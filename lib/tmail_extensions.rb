# lib/tmail_extensions.rb:
# Extensions / fixes to TMail.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: tmail_extensions.rb,v 1.7 2009-10-02 23:31:01 francis Exp $
require 'racc/parser'
require 'tmail'
require 'tmail/scanner'
require 'tmail/utils'
require 'tmail/interface'

# Monkeypatch!

# These mainly used in app/models/incoming_message.rb
module TMail
    class Mail
        # Monkeypatch! (check to see if this becomes a standard function in
        # TMail::Mail, then use that, whatever it is called)
        def Mail.get_part_file_name(part)
            file_name = (part['content-location'] &&
                          part['content-location'].body) ||
                        part.sub_header("content-type", "name") ||
                        part.sub_header("content-disposition", "filename")
            file_name = file_name.strip if file_name
            file_name
        end

        # Monkeypatch! Generalisation of To:, Cc:
        def envelope_to(default = nil)
            # XXX assumes only one envelope-to, and no parsing needed
            val = self.header_string('envelope-to')
            return val ? [val,] : []
        end

    end

    module TextUtils
        # Monkeypatch! Much more aggressive list of characters to cause quoting
        # than in normal TMail. e.g. Have found real cases where @ needs quoting.
        # We list characters to allow, rather than characters not to allow.
        NEW_PHRASE_UNSAFE=/[^A-Za-z0-9!#\$%&'*+\-\/=?^_`{|}~ ]/n
        def quote_phrase( str )
          (NEW_PHRASE_UNSAFE === str) ? dquote(str) : str
        end
    end
end

# Monkeypatch! TMail 1.2.7.1 will parse only one address out of a list of addresses with
# unquoted display parts https://github.com/mikel/tmail/issues#issue/9 - this monkeypatch
# fixes this issue.
module TMail

  class Parser < Racc::Parser

module_eval <<'..end lib/tmail/parser.y modeval..id2dd1c7d21d', 'lib/tmail/parser.y', 340

  def self.special_quote_address(str) #:nodoc:
    # Takes a string which is an address and adds quotation marks to special
    # edge case methods that the RACC parser can not handle.
    #
    # Right now just handles two edge cases:
    #
    # Full stop as the last character of the display name:
    #   Mikel L. <mikel@me.com>
    # Returns:
    #   "Mikel L." <mikel@me.com>
    #
    # Unquoted @ symbol in the display name:
    #   mikel@me.com <mikel@me.com>
    # Returns:
    #   "mikel@me.com" <mikel@me.com>
    #
    # Any other address not matching these patterns just gets returned as is.
    case
    # This handles the missing "" in an older version of Apple Mail.app
    # around the display name when the display name contains a '@'
    # like 'mikel@me.com <mikel@me.com>'
    # Just quotes it to: '"mikel@me.com" <mikel@me.com>'
    when str =~ /\A([^"][^<]+@[^>]+[^"])\s(<.*?>)\Z/
      return "\"#{$1}\" #{$2}"
    # This handles cases where 'Mikel A. <mikel@me.com>' which is a trailing
    # full stop before the address section.  Just quotes it to
    # '"Mikel A." <mikel@me.com>'
    when str =~ /\A(.*?\.)\s(<.*?>)\s*\Z/
      return "\"#{$1}\" #{$2}"
    else
      str
    end
  end

..end lib/tmail/parser.y modeval..id2dd1c7d21d
  end   # class Parser

end   # module TMail


