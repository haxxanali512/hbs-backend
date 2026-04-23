module ReferralPartners
  class CodeGenerator
    LENGTH = 8
    ALPHABET = ("A".."Z").to_a.concat(("0".."9").to_a).freeze

    def self.generate
      loop do
        code = Array.new(LENGTH) { ALPHABET.sample }.join
        return code unless ReferralPartner.exists?(referral_code: code)
      end
    end
  end
end
