require 'line/bot'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = Rails.application.credentials.linebot[:LINE_CHANNEL_SECRET]
      config.channel_token = Rails.application.credentials.linebot[:LINE_CHANNEL_TOKEN]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          if event.message['text'].start_with?("/")
            text = 'コマンド'
          else
            google_cloud_language_client = GoogleCloudLanguageClient.new
            response = google_cloud_language_client.analyze_sentiment(text: event.message['text'])
            score = response.document_sentiment.score.to_f.round(1)
            text = "ポジティブ度: #{score}"
          end

          message = {
            type: 'text',
            text: text
          }
          client.reply_message(event['replyToken'], message)

        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }
    head :ok
  end
end
