# Monkeypatch! Adding some extra members to store extra info in.
module Mail
    class Message
        attr_accessor :url_part_number
        attr_accessor :rfc822_attachment # when a whole email message is attached as text
        attr_accessor :within_rfc822_attachment # for parts within a message attached as text (for getting subject mainly)
        attr_accessor :count_parts_count
        attr_accessor :count_first_uudecode_count
        def initialize(*args, &block)
          @body = nil
          @body_raw = nil
          @separate_parts = false
          @text_part = nil
          @html_part = nil
          @errors = nil
          @header = nil
          @charset = 'UTF-8'
          @defaulted_charset = true

          @perform_deliveries = true
          @raise_delivery_errors = true

          @delivery_handler = nil

          @delivery_method = Mail.delivery_method.dup

          @transport_encoding = Mail::Encodings.get_encoding('7bit')

          @mark_for_delete = false

          if args.flatten.first.respond_to?(:each_pair)
            init_with_hash(args.flatten.first)
          else
            init_with_string(args.flatten[0].to_s)
          end

          if block_given?
            instance_eval(&block)
          end

          self
        end
    end
end

module MailParsingWithMail

    include MailParsingGeneral

    def MailParsingWithMail.mail_from_raw_email(data)
       mail = Mail.new(data)
       mail
    end

    def MailParsingWithMail.first_from(mail)
        if mail[:from]
            begin
                mail[:from].addrs[0]
                mail[:from].decoded
                return mail[:from].addrs[0]
            rescue
                return mail[:from].value
            end
        else
            nil
        end
    end

    def MailParsingWithMail.get_from_name(mail)
        first_from = first_from(mail)
        if first_from
            if first_from.is_a?(String)
                return nil
            else
                return first_from.display_name ? eval(%Q{"#{first_from.display_name}"}) : nil
            end
        else
            return nil
        end
    end

    def MailParsingWithMail.get_from_address(mail)
        first_from = first_from(mail)
        if first_from
            if first_from.is_a?(String)
                return nil
            else
                return first_from.address
            end
        else
            return nil
        end
    end

    def MailParsingWithMail.get_envelope_to_address(mail)
        if envelope_to = mail['envelope-to']
            return [envelope_to.value]
        else
            return []
        end
    end

    def MailParsingWithMail.empty_return_path?(mail)
        return false if mail['return-path'].nil?
        return true if mail['return-path'].value.blank?
        return false
    end

    def MailParsingWithMail.get_auto_submitted(mail)
        mail['auto-submitted'] ? mail['auto-submitted'].value : nil
    end

    def MailParsingWithMail.get_part_file_name(mail_part)
        mail_part.filename
    end

    def MailParsingWithMail.get_part_body(mail_part)
        mail_part.body.decoded
    end

    def MailParsingWithMail.expand_and_normalize_parts(part, parent_mail)
        if part.multipart?
          part.parts.each{ |sub_part| expand_and_normalize_parts(sub_part, parent_mail) }
        else
          part_filename = get_part_file_name(part)
          charset = part.charset # save this, because overwriting content_type also resets charset

          # Don't allow nil content_types
          if get_content_type(part).nil?
              part.content_type = 'application/octet-stream'
          end

          # PDFs often come with this mime type, fix it up for view code
          if get_content_type(part) == 'application/octet-stream'
              part_body = get_part_body(part)
              calc_mime = AlaveteliFileTypes.filename_and_content_to_mimetype(part_filename, part_body)
              if calc_mime
                  part.content_type = calc_mime
              end
          end

          # Use standard content types for Word documents etc.
          x= get_content_type(part)
          newx = MailParsingGeneral::normalise_content_type(x)
          part.content_type = newx

          if get_content_type(part) == 'message/rfc822'
              # An email attached as text
              part.rfc822_attachment = mail_from_raw_email(part.body)
              if part.rfc822_attachment.nil?
                  # Attached mail didn't parse, so treat as text
                  part.content_type = 'text/plain'
              end
          elsif get_content_type(part) == 'application/vnd.ms-outlook' || part_filename && AlaveteliFileTypes.filename_to_mimetype(part_filename) == 'application/vnd.ms-outlook'
              # An email attached as an Outlook file
              # e.g. http://www.whatdotheyknow.com/request/chinese_names_for_british_politi
              msg = Mapi::Msg.open(StringIO.new(part.body.decoded))
              part.rfc822_attachment = mail_from_raw_email(msg.to_mime.to_s)
              part.rfc822_attachment.ready_to_send!
              if part.rfc822_attachment.nil?
                  # Attached mail didn't parse, so treat as binary
                  part.content_type = 'application/octet-stream'
              end
          elsif get_content_type(part) == 'application/ms-tnef'
              # A set of attachments in a TNEF file
              part.rfc822_attachment = TNEF.as_mail(part.body)
              if part.rfc822_attachment.nil?
                  # Attached mail didn't parse, so treat as binary
                  part.content_type = 'application/octet-stream'
              end
          end
          if part.rfc822_attachment
              expand_and_normalize_parts(part.rfc822_attachment, parent_mail)
          end
          part.charset = charset
        end
    end

    def MailParsingWithMail.count_parts(part, parent_mail)
        if part.multipart?
            part.parts.each { |p| count_parts(p, parent_mail) }
        else
            if part.rfc822_attachment
                count_parts(part.rfc822_attachment, parent_mail)
            else
                parent_mail.count_parts_count += 1
                part.url_part_number = parent_mail.count_parts_count
            end
        end

        parent_mail.count_first_uudecode_count = parent_mail.count_parts_count
    end

    def MailParsingWithMail.choose_best_alternative(mail)
        # Choose best part from alternatives
        if mail.html_part
            return mail.html_part
        elsif mail.text_part
            return mail.text_part
        else
            return mail.parts.first
        end
    end

    def MailParsingWithMail.get_attachment_leaves(mail)
        expand_and_normalize_parts(mail, mail)
        leaves = _get_attachment_leaves_recursive(mail, nil, mail)
        mail.count_parts_count = 0
        count_parts(mail, mail)
        return leaves
    end

    def MailParsingWithMail._get_attachment_leaves_recursive(part, within_rfc822_attachment, parent_mail)
        leaves_found = []
        if part.multipart?
            if part.parts.size == 0
                raise "no parts on multipart mail"
            end

            if part.sub_type == 'alternative'
                best_part = choose_best_alternative(part)
                leaves_found += _get_attachment_leaves_recursive(best_part, within_rfc822_attachment, parent_mail)
            else
                # Add all parts
                part.parts.each do |m|
                    leaves_found += _get_attachment_leaves_recursive(m, within_rfc822_attachment, parent_mail)
                end
            end
        else
            if part.rfc822_attachment
                leaves_found += _get_attachment_leaves_recursive(part.rfc822_attachment, part.rfc822_attachment, parent_mail)
            else
                # Store leaf
                part.within_rfc822_attachment = within_rfc822_attachment
                leaves_found += [part]
            end
        end
        return leaves_found
    end

    def MailParsingWithMail.get_attachment_attributes(mail)
        leaves = get_attachment_leaves(mail)
        attachments = []

        for leaf in leaves
            body = get_part_body(leaf)
            if leaf.within_rfc822_attachment
                within_rfc822_subject = leaf.within_rfc822_attachment.subject
                # Test to see if we are in the first part of the attached
                # RFC822 message and it is text, if so add headers.
                # XXX should probably use hunting algorithm to find main text part, rather than
                # just expect it to be first. This will do for now though.
                if leaf.within_rfc822_attachment == leaf && get_content_type(leaf) == 'text/plain'
                    headers = ""
                    for header in [ 'Date', 'Subject', 'From', 'To', 'Cc' ]
                        if header_value = get_header_string(header, leaf.within_rfc822_attachment)
                            # Example message which has a blank Date header:
                            # http://www.whatdotheyknow.com/request/30747/response/80253/attach/html/17/Common%20Purpose%20Advisory%20Group%20Meeting%20Tuesday%202nd%20March.txt.html
                            if !header_value.blank?
                                headers = headers + header + ": " + header_value.to_s + "\n"
                            end
                        end
                    end
                    # XXX call _convert_part_body_to_text here, but need to get charset somehow
                    # e.g. http://www.whatdotheyknow.com/request/1593/response/3088/attach/4/Freedom%20of%20Information%20request%20-%20car%20oval%20sticker:%20Article%2020,%20Convention%20on%20Road%20Traffic%201949.txt
                    body = headers + "\n" + body
                end
            end
            hexdigest = Digest::MD5.hexdigest(body)
            # puts "ATTACHMENT #{body.slice(0,200)}"
            leaf_attributes = { :hexdigest => hexdigest,
                                :body => body,
                                :leaf => leaf,
                                :within_rfc822_subject => within_rfc822_subject,
                                :filename => get_part_file_name(leaf) }
            attachments << leaf_attributes
        end
        return attachments
    end

    def MailParsingWithMail.address_from_name_and_email(name, email)
        if !MySociety::Validate.is_valid_email(email)
            raise "invalid email " + email + " passed to address_from_name_and_email"
        end
        if name.nil?
            return Mail::Address.new(email)
        end
        address = Mail::Address.new
        address.display_name = name
        address.address = email
        return address
    end

    def MailParsingWithMail.convert_part_body_to_text(part)
        if part.nil?
            text = "[ Email has no body, please see attachments ]"
            source_charset = "utf-8"
        else
            text = part.body # foi_attachment should have converted this to utf-8
            source_charset = part.charset
            if get_content_type(part) == 'text/html'
                # e.g. http://www.whatdotheyknow.com/request/35/response/177
                # XXX This is a bit of a hack as it is calling a
                # convert to text routine.  Could instead call a
                # sanitize HTML one.

                # If the text isn't UTF8, it means TMail had a problem
                # converting it (invalid characters, etc), and we
                # should instead tell elinks to respect the source
                # charset
                use_charset = "utf-8"
                # begin

                    # text.encode('utf-8')
                # rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
                    # use_charset = source_charset
                # end
                text = MailParsingGeneral._get_attachment_text_internal_one_file(part.content_type, text, use_charset)
            end
        end
        text = MailParsing.sanitize_text(text, source_charset)

        # Fix DOS style linefeeds to Unix style ones (or other later regexps won't work)
        # Needed for e.g. http://www.whatdotheyknow.com/request/60/response/98
        text = text.gsub(/\r\n/, "\n")

        # Compress extra spaces down to save space, and to stop regular expressions
        # breaking in strange extreme cases. e.g. for
        # http://www.whatdotheyknow.com/request/spending_on_consultants
        text = text.gsub(/ +/, " ")
    end

    def MailParsingWithMail.sanitize_text(text, source_charset)
        begin
            text.encode('utf-8')
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
            source_charset = 'utf-8' if source_charset.nil?
            begin
                text = text.encode("utf-8", :invalid => :replace, :undef => :replace, :replace => "") +
                    _("\n\n[ {{site_name}} note: The above text was badly encoded, and has had strange characters removed. ]",
                      :site_name => MySociety::Config.get('SITE_NAME', 'Alaveteli'))
            rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
                if source_charset != "utf-8"
                    source_charset = "utf-8"
                    retry
                end
            end
        end
        text
    end

    def MailParsingWithMail.get_content_type(part)
        part.content_type ? part.content_type.split(';')[0] : nil
    end

    def MailParsingWithMail.get_header_string(header, mail)
        mail.header[header] ? mail.header[header].to_s : nil
    end
end

