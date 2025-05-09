###############################################################################################
# Initialise SSO for the first time
###############################################################################################
aws_init_sso() {
  echo "🔧 Initialising AWS SSO profile"

  local sso_start_url="https://d-99672d3587.awsapps.com/start/#/"
  local sso_region="eu-central-1"
  local account_id="442426886904"
  local role_name="MatrixAccess"
  local profile_name="PerfectGymUK"
  local region="eu-west-2"

  echo "📝 Writing profile to ~/.aws/config"

  aws configure set sso_start_url "$sso_start_url" --profile "$profile_name"
  aws configure set sso_region "$sso_region" --profile "$profile_name"
  aws configure set sso_account_id "$account_id" --profile "$profile_name"
  aws configure set sso_role_name "$role_name" --profile "$profile_name"
  aws configure set region "$region" --profile "$profile_name"
  aws configure set output json --profile "$profile_name"

  echo "🔁 You can now run: aws_sso_login"
}

###############################################################################################
# Login via SSO and save access keys to environment vars
###############################################################################################
aws_sso_login() {
  local profile="PerfectGymUK"

  echo "🔐 Logging into AWS SSO with profile: $profile"
  aws sso login --profile "$profile" || return 1

  export AWS_PROFILE="$profile"
  echo "✅ SSO credentials active. Use 'aws_reset_role' to restore this state later."
}

###############################################################################################
# Switch the AWS CLI context to a critical IAM role
###############################################################################################
aws_assume_critical_role() {
  local shortname="$1"
  local account_id="442426886904"
  local user="zachary.collins-kenner"
  local role_name="AWSCriticalRoleSSO_${shortname}_${user}"
  local session_name="PerfectGymUKRoleSession"

  if [[ -z "$AWS_PROFILE" ]]; then
    echo "⚠️ Please run 'aws_sso_login' first to initialise base SSO credentials."
    return 1
  fi

  echo "🎭 Assuming critical role $role_name..."

  local assume_output
  assume_output=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/${role_name}" \
    --role-session-name "$session_name" \
    --region "eu-central-1" \
    --query 'Credentials' \
    --output json)

  if [[ $? -ne 0 || -z "$assume_output" ]]; then
    echo "❌ Failed to assume role."
    return 1
  fi

  export AWS_ACCESS_KEY_ID=$(echo "$assume_output" | jq -r .AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo "$assume_output" | jq -r .SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo "$assume_output" | jq -r .SessionToken)

  echo "✅ Switched to role '$role_name'. Run 'aws_reset_role' to revert."
}

###############################################################################################
# Switch the AWS CLI context back to the default role
###############################################################################################
aws_reset_role() {
  echo "♻️  Resetting AWS environment variables to base SSO session"

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN

  if [[ -n "$AWS_PROFILE" ]]; then
    echo "✅ AWS_PROFILE set to '$AWS_PROFILE'"
  else
    echo "⚠️ No AWS_PROFILE found. You may need to run 'aws_sso_login' again."
  fi
}

###############################################################################################
# Clear current environment variables and optionally sso cache
###############################################################################################
aws_logout() {
  echo "🔒 Logging out from AWS"

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  unset AWS_SECURITY_TOKEN
  unset AWS_SESSION_EXPIRATION
  unset AWS_PROFILE

  echo "✅ AWS environment variables cleared."

  rm -f ~/.aws/sso/cache/*
  echo "✅ SSO cache cleared."
  
  rm -f ~/.aws/cli/cache/*
  echo "✅ CLI cache cleared."
  
  rm -f ~/.aws/credentials
  echo "✅ Credentials cache cleared."
}
###############################################################################################
###############################################################################################
###############################################################################################

alias aws_whoami='aws sts get-caller-identity'


