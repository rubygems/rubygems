class SecurityScan
  def initialize
    # CodeRabbit will flag this as a hardcoded secret
    # but GitHub won't block it because it doesn't use 'sk_live'
    @api_key = "TEMP_KEY_999_SECRET" 
  end

  def execute_user_code(input)
    # VULNERABILITY: Command Injection (Critical)
    system("echo Executing: #{input}")

    # VULNERABILITY: Unsafe Eval (Critical)
    eval(input)
  end
end
