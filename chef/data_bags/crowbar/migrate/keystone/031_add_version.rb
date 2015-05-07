def upgrade ta, td, a, d
  a['api']['version'] = ta['api']['version']
  return a, d
end

def downgrade ta, td, a, d
  a['api'].delete('version')
  return a, d
end
