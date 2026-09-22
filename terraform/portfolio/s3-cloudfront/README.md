# Static website deployment using S3 and CloudFront

This example is hosting the same application as [its ECS neighbor](../ecs), in a different, more cost effective way.
For this, we chose to host the static built files instead of deploying a Docker image.

## "Backend" - S3 storage
- this part has been rather simple, an S3 bucket , with enabled versioning, server-side encrypted and private
- built application is then synced into it with `aws s3 sync dist/ s3://<bucket URL>/ --delete`

## "Frontend" - CloudFront
- we configure an AWS CloudFront Distribution to use the private S3 bucket as an origin, and serve what is hosted in the bucket

### CloudFront -> S3 bucket access
- first we need to give access to the S3 for the CloudFront Distribution
- we created an IAM policy that allows CloudFront (`principals.identifiers`) with specific ARN to the one we created (`condition.values[]`) to get S3 objects in a bucket that we created (`resources`)
- we then attach this policy to the S3 bucket
- we create a CloudFront Origin Access Control, which we'll use as an identity to access the S3 (details down below)

### CloudFront Distribution itself
- important bits here are the references to the origin:
  - regional domain name for the S3 bucket
  - reference to the OAC we created earlier
- define the entrypoint (`index.html`), price class, and other required parameters
  - `default_cache_behavior` that doesn't forward cookies and redirects HTTP to HTTPS and only allows `GET/HEAD/OPTIONS`
  - `restrictions` block that can restrict the site from geographical standpoint
  - `custom_error_response` that shows our custom error page on errors which actually turned out to be 403 instead of 404

### Custom domain
- in order to host the site on a custom domain, we need:
  - valid TLS certificate - we can provision that with ACM
  - DNS record

#### ACM Certificate
- we chose a DNS validation method
- CloudFront is a global resource, but still has to be "assigned" to a region, AWS canonically chose the first region - `us-east-1`
- this is why even certificates CF uses have to be defined there, even if rest of the infra isn't
- subsequent service for validating the certificate also has to be created there

##### DNS cert validation
- the `certificate` resource exposes `domain_validation_options`, which we can use to create correspondent DNS records
- these have to be created in the appropriate DNS zone

#### DNS record
- last thing on the list is a DNS record for our CF Distribution
- created in the same zone/s the Distribution is listed for
- in order to refer to the Distribution, we use the `alias` block, referring to the domain and zone of the Distribution

---
After running `tofu apply`, it takes around 4 minutes for the Distribution to be available with verified certificate and valid DNS record.

## Deployment
- deploying of a new version is very easy:
  - build the new static files for the website
  - `aws s3 sync dist/ s3://<bucket>/ --delete --profile aws-learning`
  - at this point, files are updated, but CloudFront might still be serving cached assets, so we trigger a cache invalidation
  - `aws cloudfront create-invalidation --distribution-id <id> --paths "/*" --profile aws-learning`

## Future improvements
- the main problem would be probably better security against DDOS / spambot attacks
- CloudFront Shield already mitigates that on L2/L3 level, but an attacker could just spam `GET /` millions of times and that is essentially a valid traffic
- best defense against that would be AWS WAF, set to perhaps some rate limiting per IP or similar measures