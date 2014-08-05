def upgrade ta, td, a, d
  a['ldap']['tls_cacertfile'] = ta['ldap']['tls_cacertfile']
  a['ldap']['tls_cacertdir'] = ta['ldap']['tls_cacertdir']
  a['ldap']['use_tls'] = ta['ldap']['use_tls']
  a['ldap']['tls_req_cert'] = ta['ldap']['tls_req_cert']
  return a, d
end

def downgrade ta, td, a, d
  a['ldap'].delete('tls_cacertfile')
  a['ldap'].delete('tls_cacertdir')
  a['ldap'].delete('use_tls')
  a['ldap'].delete('tls_req_cert')
  return a, d
end
