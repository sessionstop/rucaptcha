require 'spec_helper'
require 'securerandom'

describe RuCaptcha do
  class CustomSession
    attr_accessor :id

    def initialize
      self.id = SecureRandom.hex
    end
  end
  class Simple < ActionController::Base
    def session
      @session ||= CustomSession.new
    end

    def params
      @params ||= {}
    end

    def custom_session
      RuCaptcha.cache.read(self.rucaptcha_sesion_key_key)
    end

    def clean_custom_session
      RuCaptcha.cache.delete(self.rucaptcha_sesion_key_key)
    end
  end

  let(:simple) { Simple.new }

  describe '.rucaptcha_sesion_key_key' do
    it 'should work' do
      expect(simple.rucaptcha_sesion_key_key).to eq ['rucaptcha-session', simple.session.id].join(':')
    end
  end

  describe '.generate_rucaptcha' do
    it 'should work' do
      expect(RuCaptcha::Captcha).to receive(:random_chars).and_return('abcd')
      expect(simple.generate_rucaptcha).not_to be_nil
      expect(simple.custom_session[:code]).to eq('abcd')
    end
  end

  describe '.verify_rucaptcha?' do
    context 'Nil of param' do
      it 'should work when params[:_rucaptcha] is nil' do
        simple.params[:_rucaptcha] = nil
        expect(simple.verify_rucaptcha?).to eq(false)
      end

      it 'should work when session[:_rucaptcha] is nil' do
        simple.clean_custom_session
        simple.params[:_rucaptcha] = 'Abcd'
        expect(simple.verify_rucaptcha?).to eq(false)
      end
    end

    context 'Correct chars in params' do
      it 'should work' do
        RuCaptcha.cache.write(simple.rucaptcha_sesion_key_key, {
          time: Time.now.to_i,
          code: 'abcd'
        })
        simple.params[:_rucaptcha] = 'Abcd'
        expect(simple.verify_rucaptcha?).to eq(true)
        expect(simple.custom_session).to eq nil

        RuCaptcha.cache.write(simple.rucaptcha_sesion_key_key, {
          time: Time.now.to_i,
          code: 'abcd'
        })
        simple.params[:_rucaptcha] = 'AbcD'
        expect(simple.verify_rucaptcha?).to eq(true)
      end
    end

    describe 'Incorrect chars' do
      it 'should work' do
        RuCaptcha.cache.write(simple.rucaptcha_sesion_key_key, {
          time: Time.now.to_i - 60,
          code: 'abcd'
        })
        simple.params[:_rucaptcha] = 'd123'
        expect(simple.verify_rucaptcha?).to eq(false)
        expect(simple.custom_session).to eq nil
      end
    end

    describe 'Expires Session key' do
      it 'should work' do
        RuCaptcha.cache.write(simple.rucaptcha_sesion_key_key, {
          time: Time.now.to_i - 121,
          code: 'abcd'
        })
        simple.params[:_rucaptcha] = 'abcd'
        expect(simple.verify_rucaptcha?).to eq(false)
      end
    end
  end
end
