def upgrade ta, td, a, d
  unless a['api'].has_key? 'region'
    a['api']['region'] = ta['api']['region']
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta['api'].has_key? 'region'
    a['api'].delete('region')
  end
  return a, d
end
