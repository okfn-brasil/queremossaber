require 'tmpdir'

class TNEF

    def self.get_attachments(content)
        attachments = []
        Dir.mktmpdir do |dir|
            IO.popen("#{`which tnef`.chomp} -K -C #{dir}", "wb") do |f|
                f.write(content)
                f.close
                if $?.signaled?
                    raise IOError, "tnef exited with signal #{$?.termsig}"
                end
                if $?.exited? && $?.exitstatus != 0
                    raise IOError, "tnef exited with status #{$?.exitstatus}"
                end
            end
            found = 0
            Dir.new(dir).sort.each do |file| # sort for deterministic behaviour
                if file != "." && file != ".."
                    file_content = File.open("#{dir}/#{file}", "rb").read
                    attachments << { :content => file_content,
                                     :filename => file }
                    found += 1
                end
            end
            if found == 0
                raise IOError, "tnef produced no attachments"
            end
        end
        attachments
    end

    # Extracts all attachments from the given TNEF file as a TMail::Mail object
    # The TNEF file also contains the message body, but in general this is the
    # same as the message body in the message proper.
    def self.as_tmail(content)
        main = TMail::Mail.new
        main.set_content_type 'multipart', 'mixed', { 'boundary' => TMail.new_boundary }
        get_attachments(content).each do |attachment|
            tmail_attachment = TMail::Mail.new
            tmail_attachment['content-location'] = attachment[:filename]
            tmail_attachment.body = attachment[:content]
            main.parts << tmail_attachment
        end
        main
    end

    def self.as_mail(content)
        main = Mail.new
        get_attachments(content).each do |attachment|
            main.add_file(attachment)
        end
        main.ready_to_send!
        main
    end

end
