# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'when parsing mail with the tmail or mail gem' do

    def get_mail(filename)
        MailParsing.mail_from_raw_email(load_file_fixture(filename))
    end

    describe 'when asked to create a mail from raw email data' do

        it 'should correctly parse a multipart email with a linebreak in the boundary' do
            mail = get_mail('space-boundary.email')
            mail.parts.size.should == 2
            mail.multipart?.should == true
        end

    end


    describe 'when asked for auto_submitted' do

        it 'should return a string value for an email with an auto-submitted header' do
            mail = get_mail('autoresponse-header.email')
            MailParsing.get_auto_submitted(mail).should == 'auto-replied'
        end

        it 'should return a nil value for an email with no auto-submitted header' do
            mail = get_mail('incoming-request-plain.email')
            MailParsing.get_auto_submitted(mail).should == nil
        end

    end

    describe 'when asked if there is an empty return path' do

        it 'should return true if there is an empty return-path specified' do
            mail = get_mail('empty-return-path.email')
            MailParsing.empty_return_path?(mail).should == true
        end

        it 'should return false if there is no return-path header' do
            mail = get_mail('incoming-request-attach-attachments.email')
            MailParsing.empty_return_path?(mail).should == false
        end

        it 'should return false if there is a return path address' do
            mail = get_mail('autoresponse-header.email')
            MailParsing.empty_return_path?(mail).should == false
        end
    end

    describe 'when asked for the envelope_to_address' do

        it 'should return an array containing the envelope-to address if there is one' do
            mail = get_mail('humberside-police-odd-mime-type.email')
            MailParsing.get_envelope_to_address(mail).should == ['request-5335-xxxxxxxx@whatdotheyknow.com']
        end

        it 'should return an empty array if there is no envelope-to header' do
            mail = get_mail('autoresponse-header.email')
            MailParsing.get_envelope_to_address(mail).should == []
        end

    end

    describe 'when asked for the from address' do

        it 'should return nil if there is a blank "From" field' do
            mail_data = load_file_fixture('incoming-request-plain.email')
            mail_data.gsub!('EMAIL_FROM', '')
            mail = MailParsing.mail_from_raw_email(mail_data)
            MailParsing.get_from_address(mail).should == nil
        end

        it 'should correctly return an encoded name from the from field' do
            mail = get_mail('quoted-subject-iso8859-1.email')
            MailParsing.get_from_address(mail).should == 'geraldinequango@localhost'
        end

        it 'should return nil if there is no address in the "From" field' do
            mail = get_mail('track-response-webshield-bounce.email')
            MailParsing.get_from_address(mail).should == nil
        end

        it 'should return the "From" email address if there is one' do
             mail = get_mail('track-response-abcmail-oof.email')
            MailParsing.get_from_address(mail).should == 'Name.Removed@example.gov.uk'
        end

        it 'should get an address from a "From" field with a name and address' do
            mail = get_mail('incoming-request-oft-attachments.email')
            MailParsing.get_from_address(mail).should == 'public@authority.gov.uk'
        end
    end

    describe 'when asked for the from name' do

        it 'should return nil if there is a blank "From" field' do
            mail_data = load_file_fixture('incoming-request-plain.email')
            mail_data.gsub!('EMAIL_FROM', '')
            mail = MailParsing.mail_from_raw_email(mail_data)
            MailParsing.get_from_name(mail).should == nil
        end

        it 'should correctly return an encoded name from the from field' do
            mail = get_mail('quoted-subject-iso8859-1.email')
            MailParsing.get_from_name(mail).should == 'Coordenação de Relacionamento, Pesquisa e Informação/CEDI'
        end

        it 'should get a name from a "From" field with a name and address' do
            mail = get_mail('incoming-request-oft-attachments.email')
            MailParsing.get_from_name(mail).should == 'Public Authority'
        end

        it 'should return nil from a "From" field that is just a name'do
            mail = get_mail('track-response-webshield-bounce.email')
            MailParsing.get_from_name(mail).should == nil
        end

    end

    describe 'when normalizing content types' do
    end

end