module MailParsingWithMail

    def MailParsingWithMail.mail_from_raw_email(data)
       Mail.new(data)
    end

end