def upgrade ta, td, a, d
  unless a.has_key? "multi_domain_support"
    a["domain_specific_drivers"] = ta["domain_specific_drivers"]
    a["domain_config_dir"] = ta["domain_config_dir"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.has_key? "multi_domain_support"
    a.delete("domain_specific_drivers")
    a.delete("domain_config_dir")
  end
  return a, d
end
