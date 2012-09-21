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

    def MailParsingWithMail.get_from_address(mail)
        first_from = first_from(mail)
        first_from ? first_from.address : nil
    end

end