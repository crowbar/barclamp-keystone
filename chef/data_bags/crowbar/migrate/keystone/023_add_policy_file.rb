def upgrade ta, td, a, d
  a['policy_file'] = ta['policy_file']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('policy_file')
  return a, d
end
