module MailParsingGeneral

    def MailParsingGeneral::normalise_content_type(content_type)
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

    def MailParsingGeneral._get_attachment_text_internal_one_file(content_type, body, charset = 'utf-8')
        # note re. charset: TMail always tries to convert email bodies
        # to UTF8 by default, so normally it should already be that.
        text = ''
        # XXX - tell all these command line tools to return utf-8
        if content_type == 'text/plain'
            text += body + "\n\n"
        else
            tempfile = Tempfile.new('foiextract')
            tempfile.binmode
            tempfile.print body
            tempfile.flush
            if content_type == 'application/vnd.ms-word'
                AlaveteliExternalCommand.run("wvText", tempfile.path, tempfile.path + ".txt")
                # Try catdoc if we get into trouble (e.g. for InfoRequestEvent 2701)
                if not File.exists?(tempfile.path + ".txt")
                    AlaveteliExternalCommand.run("catdoc", tempfile.path, :append_to => text)
                else
                    text += File.read(tempfile.path + ".txt") + "\n\n"
                    File.unlink(tempfile.path + ".txt")
                end
            elsif content_type == 'application/rtf'
                # catdoc on RTF prodcues less comments and extra bumf than --text option to unrtf
                AlaveteliExternalCommand.run("catdoc", tempfile.path, :append_to => text)
            elsif content_type == 'text/html'
                # lynx wordwraps links in its output, which then don't
                # get formatted properly by Alaveteli. We use elinks
                # instead, which doesn't do that.
                AlaveteliExternalCommand.run("elinks", "-eval", "set document.codepage.assume = \"#{charset}\"", "-eval", "set document.codepage.force_assumed = 1", "-dump-charset", "utf-8", "-force-html", "-dump",
                    tempfile.path, :append_to => text, :env => {"LANG" => "C"})
            elsif content_type == 'application/vnd.ms-excel'
                # Bit crazy using /usr/bin/strings - but xls2csv, xlhtml and
                # py_xls2txt only extract text from cells, not from floating
                # notes. catdoc may be fooled by weird character sets, but will
                # probably do for UK FOI requests.
                AlaveteliExternalCommand.run("/usr/bin/strings", tempfile.path, :append_to => text)
            elsif content_type == 'application/vnd.ms-powerpoint'
                # ppthtml seems to catch more text, but only outputs HTML when
                # we want text, so just use catppt for now
                AlaveteliExternalCommand.run("catppt", tempfile.path, :append_to => text)
            elsif content_type == 'application/pdf'
                AlaveteliExternalCommand.run("pdftotext", tempfile.path, "-", :append_to => text)
            elsif content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                # This is Microsoft's XML office document format.
                # Just pull out the main XML file, and strip it of text.
                xml = AlaveteliExternalCommand.run("/usr/bin/unzip", "-qq", "-c", tempfile.path, "word/document.xml")
                if !xml.nil?
                    doc = REXML::Document.new(xml)
                    text += doc.each_element( './/text()' ){}.join(" ")
                end
            elsif content_type == 'application/zip'
                # recurse into zip files
                begin
                    zip_file = Zip::ZipFile.open(tempfile.path)
                    text += IncomingMessage._get_attachment_text_from_zip_file(zip_file)
                    zip_file.close()
                rescue
                    $stderr.puts("Error processing zip file: #{$!.inspect}")
                end
            end
            tempfile.close
        end

        if text.respond_to? :force_encoding
            text.force_encoding('utf-8')
        else
            text
        end
    end

end