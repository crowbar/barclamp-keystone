# This migration reverts migration 001
# Since 001 was lossy, there is no way to restore the value that was
# in there before. The admin has to go in and manually fix it up.

def upgrade ta, td, a, d
  a['ldap']['user_enabled_default'] = ta['ldap']['user_enabled_default']
  return a, d
end

def downgrade ta, td, a, d
  a['ldap']['user_enabled_default'] = true
  return a, d
end
