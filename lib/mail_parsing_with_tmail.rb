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

    def MailParsingWithTmail.get_from_address(mail)
        if mail.from_addrs.nil? || mail.from_addrs.size == 0
            return nil
        end
        mail.from_addrs[0].spec
    end


end
