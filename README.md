# From K8s to AWS
This is an IaC for my learning journey in AWS. Extra focus on documenting the progress myself, code assisted by but not written by, Claude. 

## Troubleshooting
- `aws` CLI works in sessions, and SSO sessions expire (in the order of hours, but they do). If something doesn't work, try relogging first:
    ```shell
    aws sso login --profile aws-learning
    ```
