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
