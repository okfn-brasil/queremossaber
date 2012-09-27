# Monkeypatch! Adding some extra members to store extra info in.
module TMail
    class Mail
        attr_accessor :url_part_number
        attr_accessor :rfc822_attachment # when a whole email message is attached as text
        attr_accessor :within_rfc822_attachment # for parts within a message attached as text (for getting subject mainly)
    end
end


module MailParsingWithTmail

    def MailParsingWithTmail.mail_from_raw_email(data)
        # Hack round bug in TMail's MIME decoding. Example request which provokes it:
        # http://www.whatdotheyknow.com/request/reviews_of_unduly_lenient_senten#incoming-4830
        # Report of TMail bug:
        # http://rubyforge.org/tracker/index.php?func=detail&aid=21810&group_id=4512&atid=17370
        copy_of_raw_data = data.gsub(/; boundary=\s+"/im,'; boundary="')

        mail = TMail::Mail.parse(copy_of_raw_data)
        mail.base64_decode
        return mail
    end

    # XXX can probably remove from_name_if_present (which is a
    # monkey patch) by just calling .from_addrs[0].name here
    # instead?
    def MailParsingWithTmail.get_from_name(mail)
        mail.from_name_if_present
    end

    def MailParsingWithTmail.get_from_address(mail)
        if mail.from_addrs.nil? || mail.from_addrs.size == 0
            return nil
        end
        mail.from_addrs[0].spec
    end

    def MailParsingWithTmail.get_envelope_to_address(mail)
        mail.envelope_to
    end

    def MailParsingWithTmail.get_part_file_name(mail_part)
        part_file_name = TMail::Mail.get_part_file_name(mail_part)
        if part_file_name.nil?
            return nil
        end
        part_file_name = part_file_name.dup
        return part_file_name
    end

    def MailParsingWithTmail.get_part_body(mail_part)
        mail_part.body
    end

    # (This risks losing info if the unchosen alternative is the only one to contain
    # useful info, but let's worry about that another time)
    def MailParsingWithTmail.get_attachment_leaves(mail)
        return _get_attachment_leaves_recursive(mail)
    end

    def MailParsingWithTmail._get_attachment_leaves_recursive(curr_mail, within_rfc822_attachment = nil)
        leaves_found = []
        if curr_mail.multipart?
            if curr_mail.parts.size == 0
                raise "no parts on multipart mail"
            end

            if curr_mail.sub_type == 'alternative'
                # Choose best part from alternatives
                best_part = nil
                # Take the last text/plain one, or else the first one
                curr_mail.parts.each do |m|
                    if not best_part
                        best_part = m
                    elsif m.content_type == 'text/plain'
                        best_part = m
                    end
                end
                # Take an HTML one as even higher priority. (They tend
                # to render better than text/plain, e.g. don't wrap links here:
                # http://www.whatdotheyknow.com/request/amount_and_cost_of_freedom_of_in#incoming-72238 )
                curr_mail.parts.each do |m|
                    if m.content_type == 'text/html'
                        best_part = m
                    end
                end
                leaves_found += _get_attachment_leaves_recursive(best_part, within_rfc822_attachment)
            else
                # Add all parts
                curr_mail.parts.each do |m|
                    leaves_found += _get_attachment_leaves_recursive(m, within_rfc822_attachment)
                end
            end
        else
            # XXX Yuck. this section alters various content_type's. That puts
            # it into conflict with ensure_parts_counted which it has to be
            # called both before and after.  It will fail with cases of
            # attachments of attachments etc.
            charset = curr_mail.charset # save this, because overwriting content_type also resets charset
            # Don't allow nil content_types
            if curr_mail.content_type.nil?
                curr_mail.content_type = 'application/octet-stream'
            end
            # PDFs often come with this mime type, fix it up for view code
            if curr_mail.content_type == 'application/octet-stream'
                part_file_name = self.get_part_file_name(curr_mail)
                part_body = MailParsing.get_part_body(curr_mail)
                calc_mime = AlaveteliFileTypes.filename_and_content_to_mimetype(part_file_name, part_body)
                if calc_mime
                    curr_mail.content_type = calc_mime
                end
            end

            # Use standard content types for Word documents etc.
            curr_mail.content_type = normalise_content_type(curr_mail.content_type)
            if curr_mail.content_type == 'message/rfc822'
                ensure_parts_counted # fills in rfc822_attachment variable
                if curr_mail.rfc822_attachment.nil?
                    # Attached mail didn't parse, so treat as text
                    curr_mail.content_type = 'text/plain'
                end
            end
            if curr_mail.content_type == 'application/vnd.ms-outlook' || curr_mail.content_type == 'application/ms-tnef'
                ensure_parts_counted # fills in rfc822_attachment variable
                if curr_mail.rfc822_attachment.nil?
                    # Attached mail didn't parse, so treat as binary
                    curr_mail.content_type = 'application/octet-stream'
                end
            end
            # If the part is an attachment of email
            if curr_mail.content_type == 'message/rfc822' || curr_mail.content_type == 'application/vnd.ms-outlook' || curr_mail.content_type == 'application/ms-tnef'
                ensure_parts_counted # fills in rfc822_attachment variable
                leaves_found += _get_attachment_leaves_recursive(curr_mail.rfc822_attachment, curr_mail.rfc822_attachment)
            else
                # Store leaf
                curr_mail.within_rfc822_attachment = within_rfc822_attachment
                leaves_found += [curr_mail]
            end
            # restore original charset
            curr_mail.charset = charset
        end
        return leaves_found
    end

    def MailParsingWithTmail.normalise_content_type(content_type)
        # e.g. http://www.whatdotheyknow.com/request/93/response/250
        if content_type == 'application/excel' or content_type == 'application/msexcel' or content_type == 'application/x-ms-excel'
            content_type = 'application/vnd.ms-excel'
        end
        if content_type == 'application/mspowerpoint' or content_type == 'application/x-ms-powerpoint'
            content_type = 'application/vnd.ms-powerpoint'
        end
        if content_type == 'application/msword' or content_type == 'application/x-ms-word'
            content_type = 'application/vnd.ms-word'
        end
        if content_type == 'application/x-zip-compressed'
            content_type = 'application/zip'
        end

        # e.g. http://www.whatdotheyknow.com/request/copy_of_current_swessex_scr_opt#incoming-9928
        if content_type == 'application/acrobat'
            content_type = 'application/pdf'
        end

        return content_type
    end

end
