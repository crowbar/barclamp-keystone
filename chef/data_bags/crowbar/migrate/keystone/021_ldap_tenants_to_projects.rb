def upgrade ta, td, a, d
  %w{ tree_dn filter objectclass domain_id_attribute id_attribute member_attribute name_attribute desc_attribute enabled_attribute attribute_ignore allow_create allow_update allow_delete enabled_emulation enabled_emulation_dn }.each do |attr|
    a['ldap']["project_#{attr}"] = a['ldap']["tenant_#{attr}"] || ta['ldap']["project_#{attr}"]
    a['ldap'].delete "tenant_#{attr}"
  end

  return a, d
end

def downgrade ta, td, a, d
  %w{ tree_dn filter objectclass domain_id_attribute id_attribute member_attribute name_attribute desc_attribute enabled_attribute attribute_ignore allow_create allow_update allow_delete enabled_emulation enabled_emulation_dn }.each do |attr|
    a['ldap']["tenant_#{attr}"] = a['ldap']["project_#{attr}"] || ta['ldap']["tenant_#{attr}"]
    a['ldap'].delete "project_#{attr}"
  end

  return a, d
end
