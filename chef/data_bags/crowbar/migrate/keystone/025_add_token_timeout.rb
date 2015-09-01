def upgrade ta, td, a, d
  unless a.has_key? "token_expiration"
    a["token_expiration"] = ta["token_expiration"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.has_key? "token_expiration"
    a.delete("token_expiration")
  end
  return a, d
end
