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
                return first_from.display_name ? "#{first_from.display_name.to_s}" : nil

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

    def MailParsingWithMail.get_attachment_leaves(mail)
        []
    end

    def MailParsingWithMail.get_attachment_attributes(mail)
        []
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


end

