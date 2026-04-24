module ReferralPartners
  class CodeGenerator
    ALPHABET = ("A".."Z").to_a.concat(("0".."9").to_a).freeze
    LENGTH = 8

    def self.call
      loop do
        code = Array.new(LENGTH) { ALPHABET.sample }.join
        return code unless ::ReferralPartner.exists?(referral_code: code)
      end
    end
  end
end
