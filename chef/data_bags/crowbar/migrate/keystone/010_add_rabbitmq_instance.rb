def upgrade ta, td, a, d
  # 'default' is the name of the rabbitmq proposal that is created, and we need
  # to reference it
  a['rabbitmq_instance'] = 'default'
  return a, d
end

def downgrade ta, td, a, d
  a['ldap'].delete('rabbitmq_instance')
  return a, d
end
