def upgrade ta, td, a, d
  a['ldap']['user_enabled_default'] = true
  return a, d
end

def downgrade ta, td, a, d
  a['ldap']['user_enabled_default'] = 'true'
  return a, d
end
