def upgrade ta, td, a, d
  a['ldap']['user_enabled_invert'] = ta['ldap']['user_enabled_invert']
  a['ldap']['use_pool'] = ta['ldap']['use_pool']
  return a, d
end

def downgrade ta, td, a, d
  a['ldap'].delete('user_enabled_invert')
  a['ldap'].delete('use_pool')
  return a, d
end
