def upgrade ta, td, a, d
  a['api'].delete('api_port')
  return a, d
end

def downgrade ta, td, a, d
  a['api']['api_port'] = a['api']['service_port']
  return a, d
end
