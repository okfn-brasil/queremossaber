# Monkeypatch! Adding some extra members to store extra info in.
module Mail
    class Message
        attr_accessor :url_part_number
        attr_accessor :rfc822_attachment # when a whole email message is attached as text
        attr_accessor :within_rfc822_attachment # for parts within a message attached as text (for getting subject mainly)
    end
end

module MailParsingWithMail

    def MailParsingWithMail.mail_from_raw_email(data)
       Mail.new(data)
    end

    def MailParsingWithMail.first_from(mail)
        if mail[:from] && mail[:from].addrs[0]
            mail[:from].decoded
            mail[:from].addrs[0]
        else
            nil
        end
    end

    def MailParsingWithMail.get_from_name(mail)
        first_from = first_from(mail)
        first_from ? first_from.name : nil
    end

    def MailParsingWithMail.get_from_address(mail)
        first_from = first_from(mail)
        first_from ? first_from.address : nil
    end

    def MailParsingWithMail.get_envelope_to_address(mail)
        if envelope_to = mail['envelope-to']
            return [envelope_to]
        else
            return []
        end
    end

    def MailParsingWithMail.get_part_file_name(mail_part)
        mail_part.filename
    end

    def MailParsingWithMail.get_part_body(mail_part)
        mail_part.body.decoded
    end

end

