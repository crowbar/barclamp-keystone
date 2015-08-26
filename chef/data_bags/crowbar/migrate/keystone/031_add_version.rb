def upgrade ta, td, a, d
  unless a['api'].has_key? 'version'
    a['api']['version'] = ta['api']['version']
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta['api'].has_key? 'version'
    a['api'].delete('version')
  end
  return a, d
end
