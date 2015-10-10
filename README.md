# Fluent::AwsElasticsearchServiceOutput

This output plugin to post to "Amazon Elasticsearch Service".

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-aws-elasticsearch-service'
```

## Usage

In your fluentd configration, use `type aws-elasticsearch-service`.

example:

```rb
source do
  type :tail
  format :apache
  time_format "%d/%b/%Y:%T %z"
  path "/var/log/nginx/access.log"
  pos_file "/var/log/td-agent/nginx.access.pos"
  tag "es.nginx.access"
end

match ("es.**") do
  type "aws-elasticsearch-service"
  type_name "access_log"
  logstash_format true
  include_tag_key true
  tag_key "@log_name"
  flush_interval "10s"

  endpoint do
    url "YOUR_ENDPOINT_URL"
    region "ap-northeast-1"
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atomita/fluent-plugin-aws-elasticsearch-service. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

