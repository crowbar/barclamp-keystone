# -*- encoding : utf-8 -*-
def upgrade ta, td, a, d
  a['assignment'] = ta['assignment']
  return a, d
end

def downgrade ta, td, a, d
  a['ldap'].delete('assignment')
  return a, d
end
