# Database Provisioner

The database provisioner is responsible for any database configuration or provisioning that is required, such as new users and schemas.

This uses Ansible in a Docker container to execute the given Ansible configuration. The container will then be deployed onto an ECS cluster as a run task.
