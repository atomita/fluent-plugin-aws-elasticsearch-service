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

```ruby
<source>
  type tail
  format apache
  time_format "%d/%b/%Y:%T %z"
  path "/var/log/nginx/access.log"
  pos_file "/var/log/td-agent/nginx.access.pos"
  tag "es.nginx.access"
</source>

<match es.**>
  type "aws-elasticsearch-service"
  type_name "access_log"
  logstash_format true
  include_tag_key true
  tag_key "@log_name"
  flush_interval 1s

  <endpoint>
    url https://CLUSTER_ENDPOINT_URL
    region eu-west-1
    # access_key_id "secret"
    # secret_access_key "seekret"
  </endpoint>
</match>
```

## IAM
If you do not wish to use credentials in your configuration via the `access_key_id` and `secret_access_key` options you should use IAM policies.

The first step is to assign an IAM instance role `ROLE` to your EC2 instances. Name it appropriately. The role should contain no policy: we're using the possession of the role as the authenticating factor and placing the policy against the ES cluster.

You should then configure a policy for the ES cluster policy thus, with appropriate substitutions for the capitalized terms:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:role/ROLE"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:eu-west-1:ACCOUNT:domain/ES_DOMAIN/*"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:eu-west-1:ACCOUNT:domain/ES_DOMAIN/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "1.2.3.4/32",
            "5.6.7.8/32"
          ]
        }
      }
    }
  ]
}
```

This will allow your fluentd hosts (by virtue of the possession of the role) and any traffic coming from the specified IP addresses (you querying Kibana) to access the various endpoints. Whilst not ideally secure (both the fluentd and Kibana boxes should ideally be restricted to the verbs they require) it should allow you to get up and ingesting logs without anything getting in your way, before you tighten down the policy.

Additionally, you can use an STS assumed role as the authenticating factor and instruct the plugin to assume this role. This is useful for cross-account access and when assigning a standard role is not possible. The endpoint configuration looks like:

```ruby
 <endpoint>
    url https://CLUSTER_ENDPOINT_URL
    region eu-west-1
    assume_role_arn arn:aws:sts::ACCOUNT:role/ROLE
    assume_role_session_name SESSION_ID # Defaults to fluentd if omitted
    sts_credentials_region us-west-2 # Defaults to region if omitted
  </endpoint>
```

The policy attached to your AWS Elasticsearch cluster then becomes something like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:sts::ACCOUNT:assumed-role/ROLE/SESSION_ID"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:eu-west-1:ACCOUNT:domain/ES_DOMAIN/*"
    }
  ]
}
```

You'll need to ensure that the environment in which the fluentd plugin runs has the capability to assume this role, by attaching a policy something like this to the instance profile:

```json
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": "sts:AssumeRole",
        "Resource": "arn:aws:iam::ACCOUNT:role/ROLE"
    }
}
```

### EKS
If you want to use IAM roles for service accounts on Amazon EKS clusters, please refer to the official documentation and specify a Service Account for your fluentd Pod.

Then, the endpoint configuration looks like:

```ruby
<endpoint>
  url https://CLUSTER_ENDPOINT_URL
  region eu-west-1
  assume_role_arn "#{ENV['AWS_ROLE_ARN']}"
  assume_role_web_identity_token_file "#{ENV['AWS_WEB_IDENTITY_TOKEN_FILE']}"
</endpoint>
```

## Troubleshooting

* "Elasticsearch::Transport::Transport::Errors::Forbidden" error="[403]" even after verifying the access keys/roles/policies.
   * Ensure you don't have a trailing slash on the endpoint URL in your fluentd configuration file (see CLUSTER_ENDPOINT_URL above).

*  "ElasticsearchIllegalArgumentException[explicit index in bulk is not allowed]"
   * Check that `rest.action.multi.allow_explicit` is set true on your Amazon ES domain (verify in the console - there's a bug in Terraform, https://github.com/hashicorp/terraform/issues/3980).

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atomita/fluent-plugin-aws-elasticsearch-service. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

