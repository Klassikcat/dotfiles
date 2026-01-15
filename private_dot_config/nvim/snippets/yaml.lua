-- YAML snippets for LuaSnip (Neovim)
-- Based on llm-snippets repository instruction templates
-- Save as: ~/.config/nvim/snippets/yaml.lua

local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt
local c = ls.choice_node
local t = ls.text_node

local snippets = {

  -- Terraform Import Task Template
  s("tf_import_task", fmt([[
requirements:
  - Language: Terraform
  - Task: Infrastructure as Code (IaC)
  - Skill Level: {1}
  - Domain: Cloud Computing
  - Tools: Terraform CLI, AWS CLI
task:
  - title: Import Existing AWS Infrastructure into Terraform
  - retry: {2}
  - cloud info:
    - name: AWS
      profile: {3}
  - description: |
      You have an Existing AWS infrastructure that was created manually or through other means. 
      Your task is to import this existing infrastructure into Terraform so that it can be managed as code. 
      This involves identifying the resources, creating corresponding Terraform configuration files, and using the `terraform import` command to bring the resources under Terraform management.
  - target infrastructure:
    - Import:
      - {4}: {5} 
    - Create:
      - {6}: {7}
        {8}: {9}
        instruction:
          - {10}
  - target files:
    - {11}
  - steps:
    - check existing resources:
      - 1. Use the AWS Management Console or AWS CLI to list and identify the existing resources you want to import.
      - 2. Import Existing AWS Infrastructure into Terraform
      - 3. Find drift between existing resources and terraform state
      - 4. Modify terraform file to match existing resources
      - 5. Use `terraform plan` to see the changes
        - if there are no drift, proceed to the next step 
        - if there are drift, return to step 4
  - tips:
    - Use the `terraform import` command to import each resource into your Terraform state. The syntax is `terraform import <resource_type>.<resource_name> <resource_id>`.
    - After importing, run `terraform plan` to see if there are any differences between the imported resources and your Terraform configuration. Adjust your configuration files as necessary to match the existing resources.
    - If there is interactive outputs, use `var=$(aws exec) | jq` to filter the outputs
    - Make sure you should use `data` blocks to reference existing resources that you did not import.
]], {
    c(1, {t("Beginner"), t("Intermediate"), t("Advanced")}),
    i(2, "3"),
    i(3, "default"),
    i(4, "Service"),
    i(5, "Name"),
    i(6, "Service"),
    i(7, "Name"),
    i(8, "Attribute"),
    i(9, "Value"),
    i(10, "Instruction"),
    i(11, "main.tf"),
  })),

  -- Terraform Refactor Task Template
  s("tf_refactor_task", fmt([[
parameters:
  importExistingResources: {1}
  retryCounts: {2}
  awsProfile: {3}
requirements:
  - Language: Terraform
  - Task: Infrastructure as Code (IaC)
  - Skill Level: {4}
  - Domain: Cloud Computing
  - Tools: Terraform CLI, AWS CLI
task:
  - title: Refactor from monolithic infrastructure code to modular Terraform code
  - retry: {5}
  - cloud info:
    - name: AWS
      profile: {6}
  - description: |
      You're and infrastructure engineer responsible for managing cloud 
      resources using Terraform. 
      You have a monolithic Terraform configuration that defines various AWS resources. 
      Your task is to refactor this configuration into a modular structure, making 
      it easier to manage and reuse components. 
      Additionally, you need to import existing AWS infrastructure into your 
      Terraform state to ensure that all resources are tracked and managed 
      through Terraform.
  - target infrastructure:
    - Import:
      - {7}: {8} 
    - Create:
      - {9}: {10}
        {11}: {12}
        instruction:
          - {13}
  - target files:
    - {14}
  - steps:
    - check existing states:
      skipable: false
      orders:
        - step: 1
          description: Review the existing monolithic Terraform configuration and codes
            to understand the resources defined.
        - step: 2
          description: Identify logical groupings of resources that can be modularized.
        - step: 3
          description: Identify the existing AWS resources that need to be imported into 
            Terraform state.
    - refactor to modules:
      skipable: false
      orders:
        - step: 1
          description: Create separate directories for each module (e.g., VPC, EC2, S3).
        - step: 2
          description: Move the relevant resource definitions into their respective module
            files (main.tf, variables.tf, outputs.tf).
        - step: 3
          description: Update the root module to call these new modules, passing necessary
            variables.
    - import existing resources:
      skipable: true
      when: {15}
      orders:
        - step: 1
          description: Use the `terraform import` command to import each existing AWS
            resource into your Terraform state.
        - step: 2
          description: Verify the import by running `terraform plan` to ensure that the
            state matches the actual resources.
        - step: 3
          description: Adjust your Terraform configuration files as necessary to match
            the existing resources.'
        - step: 4
          description: Test the new modular configuration by running `terraform plan` and
            to ensure everything works as expected.

  - tips:
    - Use the `terraform import` command to import each resource into your Terraform 
      state. The syntax is `terraform import <resource_type>.<resource_name> <resource_id>`.
    - After importing, run `terraform plan` to see if there are any differences between
      the imported resources and your Terraform configuration. Adjust your configurati-
      on files as necessary to match the existing resources.
    - If there is interactive outputs, use `var=$(aws exec) | jq` to filter the outputs
    - Make sure you should use `data` blocks to reference existing resources that you 
      did not import.
]], {
    c(1, {t("true"), t("false")}),
    i(2, "3"),
    i(3, "default"),
    c(4, {t("Beginner"), t("Intermediate"), t("Advanced")}),
    i(5, "3"),
    i(6, "default"),
    i(7, "Service"),
    i(8, "Name"),
    i(9, "Service"),
    i(10, "Name"),
    i(11, "Attribute"),
    i(12, "Value"),
    i(13, "Instruction"),
    i(14, "main.tf"),
    i(15, "importExistingResources:false"),
  })),

  -- Generic YAML task template
  s("yaml_task", fmt([[
requirements:
  - Language: {1}
  - Task: {2}
  - Skill Level: {3}
  - Domain: {4}
  - Tools: {5}
task:
  - title: {6}
  - retry: {7}
  - description: |
      {8}
  - target:
    - {9}: {10}
  - steps:
    - {11}:
      - {12}
  - tips:
    - {13}
]], {
    i(1, "Language"),
    i(2, "Task Description"),
    c(3, {t("Beginner"), t("Intermediate"), t("Advanced")}),
    i(4, "Domain"),
    i(5, "Tools"),
    i(6, "Task Title"),
    i(7, "3"),
    i(8, "Task description here"),
    i(9, "target_type"),
    i(10, "target_value"),
    i(11, "step_name"),
    i(12, "step description"),
    i(13, "tip description"),
  })),

  -- Docker Compose template
  s("docker_compose", fmt([[
version: '{1}'
services:
  {2}:
    image: {3}
    container_name: {4}
    ports:
      - "{5}:{6}"
    environment:
      - {7}={8}
    volumes:
      - {9}:{10}
    restart: {11}
    networks:
      - {12}

networks:
  {13}:
    driver: bridge

volumes:
  {14}:
    driver: local
]], {
    i(1, "3.8"),
    i(2, "app"),
    i(3, "nginx:latest"),
    i(4, "my-app"),
    i(5, "8080"),
    i(6, "80"),
    i(7, "ENV_VAR"),
    i(8, "value"),
    i(9, "./data"),
    i(10, "/app/data"),
    c(11, {t("unless-stopped"), t("always"), t("on-failure")}),
    i(12, "app-network"),
    i(13, "app-network"),
    i(14, "app-data"),
  })),

  -- Kubernetes Deployment
  s("k8s_deployment", fmt([[
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {1}
  namespace: {2}
  labels:
    app: {3}
spec:
  replicas: {4}
  selector:
    matchLabels:
      app: {5}
  template:
    metadata:
      labels:
        app: {6}
    spec:
      containers:
      - name: {7}
        image: {8}
        ports:
        - containerPort: {9}
        env:
        - name: {10}
          value: "{11}"
        resources:
          limits:
            memory: "{12}"
            cpu: "{13}"
          requests:
            memory: "{14}"
            cpu: "{15}"
]], {
    i(1, "my-app"),
    i(2, "default"),
    i(3, "my-app"),
    i(4, "3"),
    i(5, "my-app"),
    i(6, "my-app"),
    i(7, "my-app"),
    i(8, "my-app:latest"),
    i(9, "8080"),
    i(10, "ENV_VAR"),
    i(11, "value"),
    i(12, "512Mi"),
    i(13, "500m"),
    i(14, "256Mi"),
    i(15, "250m"),
  })),

  -- Kubernetes Service
  s("k8s_service", fmt([[
apiVersion: v1
kind: Service
metadata:
  name: {1}
  namespace: {2}
spec:
  selector:
    app: {3}
  ports:
  - protocol: TCP
    port: {4}
    targetPort: {5}
  type: {6}
]], {
    i(1, "my-app-service"),
    i(2, "default"),
    i(3, "my-app"),
    i(4, "80"),
    i(5, "8080"),
    c(6, {t("ClusterIP"), t("NodePort"), t("LoadBalancer")}),
  })),

  -- GitHub Actions Workflow
  s("github_actions", fmt([[
name: {1}

on:
  push:
    branches: [ {2} ]
  pull_request:
    branches: [ {3} ]

jobs:
  {4}:
    runs-on: {5}
    
    steps:
    - uses: actions/checkout@v4
    
    - name: {6}
      uses: {7}
      with:
        {8}: {9}
    
    - name: {10}
      run: |
        {11}
    
    - name: {12}
      env:
        {13}: ${{{{ secrets.{14} }}}}
      run: |
        {15}
]], {
    i(1, "CI/CD Pipeline"),
    i(2, "main"),
    i(3, "main"),
    i(4, "build"),
    c(5, {t("ubuntu-latest"), t("windows-latest"), t("macos-latest")}),
    i(6, "Setup Node.js"),
    i(7, "actions/setup-node@v4"),
    i(8, "node-version"),
    i(9, "18"),
    i(10, "Install dependencies"),
    i(11, "npm install"),
    i(12, "Deploy"),
    i(13, "API_KEY"),
    i(14, "API_KEY"),
    i(15, "npm run deploy"),
  })),

  -- Ansible Playbook
  s("ansible_playbook", fmt([[
---
- name: {1}
  hosts: {2}
  become: {3}
  vars:
    {4}: {5}
  
  tasks:
    - name: {6}
      {7}:
        {8}: {9}
        state: {10}
      
    - name: {11}
      {12}:
        {13}: {14}
      notify: {15}
  
  handlers:
    - name: {16}
      {17}:
        {18}: {19}
        state: {20}
]], {
    i(1, "Configure server"),
    i(2, "all"),
    c(3, {t("yes"), t("no")}),
    i(4, "package_name"),
    i(5, "nginx"),
    i(6, "Install package"),
    i(7, "package"),
    i(8, "name"),
    i(9, "{{ package_name }}"),
    c(10, {t("present"), t("absent"), t("latest")}),
    i(11, "Start service"),
    i(12, "service"),
    i(13, "name"),
    i(14, "{{ package_name }}"),
    i(15, "restart service"),
    i(16, "restart service"),
    i(17, "service"),
    i(18, "name"),
    i(19, "{{ package_name }}"),
    c(20, {t("restarted"), t("started"), t("stopped")}),
  })),
}

local autosnippets = {}

return snippets, autosnippets