def upgrade ta, td, a, d
  a['domain_specific_drivers'] = ta['domain_specific_drivers']
  a['domain_config_dir'] = ta['domain_config_dir']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('domain_specific_drivers')
  a.delete('domain_config_dir')
  return a, d
end
