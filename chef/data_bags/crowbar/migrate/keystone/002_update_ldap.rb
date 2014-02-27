# -*- encoding : utf-8 -*-
def upgrade ta, td, a, d
  a['ldap'].delete('user_domain_id_attribute')
  a['ldap']['user_default_project_id_attribute'] = ''
  a['ldap'].delete('group_desc_attribute')
  a['ldap'].delete('group_domain_id_attribute')
  return a, d
end

def downgrade ta, td, a, d
  a['ldap']['user_domain_id_attribute'] = 'businessCategory'
  a['ldap'].delete('user_default_project_id_attribute')
  a['ldap']['group_desc_attribute'] = 'description'
  a['ldap']['group_domain_id_attribute'] = 'businessCategory'
  return a, d
end
