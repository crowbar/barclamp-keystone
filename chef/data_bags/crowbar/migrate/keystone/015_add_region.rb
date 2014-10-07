def upgrade ta, td, a, d
  a['api']['region'] = ta['api']['region']
  return a, d
end

def downgrade ta, td, a, d
  a['api'].delete('region')
  return a, d
end
