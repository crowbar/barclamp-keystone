# -*- encoding : utf-8 -*-
def upgrade ta, td, a, d
  a['ldap']['user_enabled_default'] = (a['ldap']['user_enabled_default'] == 'true')
  return a, d
end

def downgrade ta, td, a, d
  a['ldap']['user_enabled_default'] = a['ldap']['user_enabled_default'] ? 'true' : 'false'
  return a, d
end
