-- Terraform snippets for LuaSnip (AstroNvim)
-- Based on AWS provider (ap-northeast-2), S3 backend (dealertire-terraform-state-bucket), and aws provider 5.99.1

local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

local snippets = {

  -- AWS provider (default region ap-northeast-2)
  s("tfaws", fmt([[
provider "aws" {{
  region = "{1}"
}}
]], { i(1, "ap-northeast-2") })),

  -- AWS provider with profile
  s("tfaws_profile", fmt([[
provider "aws" {{
  region  = "{1}"
  profile = "{2}"
}}
]], { i(1, "ap-northeast-2"), i(2, "default") })),

  -- terraform required_providers with AWS version pinned (5.99.1 default)
  s("tfreqp_aws", fmt([[
terraform {{
  required_providers {{
    aws = {{
      source  = "hashicorp/aws"
      version = "{1}"
    }}
  }}
}}
]], { i(1, "5.99.1") })),

  -- S3 backend block (to embed inside terraform {})
  s("tfbackend_s3", fmt([[
backend "s3" {{
  bucket       = "{1}"
  key          = "{2}"
  region       = "{3}"
  encrypt      = {4}
  use_lockfile = {5}
}}
]], {
    i(1, "dealertire-terraform-state-bucket"),
    i(2, "tirepick-prod/database/terraform.tfstate"),
    i(3, "ap-northeast-2"),
    i(4, "true"),
    i(5, "true"),
  })),

  -- terraform block with S3 backend
  s("tfterraform_backend_s3", fmt([[
terraform {{
  backend "s3" {{
    bucket       = "{1}"
    key          = "{2}"
    region       = "{3}"
    encrypt      = {4}
    use_lockfile = {5}
  }}
}}
]], {
    i(1, "dealertire-terraform-state-bucket"),
    i(2, "tirepick-prod/database/terraform.tfstate"),
    i(3, "ap-northeast-2"),
    i(4, "true"),
    i(5, "true"),
  })),

  -- Full setup: terraform (required_providers + backend) + provider
  s("tfaws_all", fmt([[
terraform {{
  required_providers {{
    aws = {{
      source  = "hashicorp/aws"
      version = "{1}"
    }}
  }}
  backend "s3" {{
    bucket       = "{2}"
    key          = "{3}"
    region       = "{4}"
    encrypt      = {5}
    use_lockfile = {6}
  }}
}}

provider "aws" {{
  region = "{7}"
}}
]], {
    i(1, "5.99.1"),
    i(2, "dealertire-terraform-state-bucket"),
    i(3, "tirepick-prod/database/terraform.tfstate"),
    i(4, "ap-northeast-2"),
    i(5, "true"),
    i(6, "true"),
    i(7, "ap-northeast-2"),
  })),

  -- Variable template
  s("tfvar", fmt([[
variable "{1}" {{
  type        = {2}
  description = "{3}"
  default     = {4}
}}
]], { i(1, "name"), i(2, "string"), i(3, "description"), i(4, "null") })),

  -- Output template
  s("tfout", fmt([[
output "{1}" {{
  description = "{2}"
  value       = {3}
}}
]], { i(1, "name"), i(2, "output description"), i(3, "resource.type.attribute") })),

  -- Generic resource
  s("tfres", fmt([[
resource "{1}" "{2}" {{
  {3}
}}
]], { i(1, "aws_resource_type"), i(2, "name"), i(3, "# attributes") })),

  -- Generic data source
  s("tfdata", fmt([[
data "{1}" "{2}" {{
  {3}
}}
]], { i(1, "aws_data_type"), i(2, "name"), i(3, "# arguments") })),

  -- Module with version
  s("tfmod", fmt([[
module "{1}" {{
  source  = "{2}"
  version = "{3}"
  {4}
}}
]], {
    i(1, "module_name"),
    i(2, "git::https://github.com/org/repo//modules/path?ref=main"),
    i(3, ">= 1.0.0"),
    i(4, "# inputs"),
  })),

  -- Common tags locals
  s("tflocals_tags", fmt([[
locals {{
  common_tags = {{
    Project     = "{1}"
    Environment = "{2}"
    ManagedBy   = "Terraform"
  }}
}}
]], { i(1, "tirepick"), i(2, "prod") })),
}

local autosnippets = {}

return snippets, autosnippets