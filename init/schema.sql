-- ========================================================================================================
-- Timezone Config
-- ========================================================================================================
SET TIME ZONE 'Asia/Ho_Chi_Minh';


-- ========================================================================================================
-- Users table
-- ========================================================================================================
CREATE TABLE IF NOT EXISTS users (
    user_id     BIGINT          PRIMARY KEY,    -- discord.user.id --
    username    VARCHAR(255)    NOT NULL,       -- discord.user.name --
    phone       VARCHAR(32)     UNIQUE NOT NULL,
    email       VARCHAR(255)    UNIQUE NOT NULL,
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now()
);


-- ========================================================================================================
-- MT5 Accounts table (1 account is assign with 1 EA)
-- 
CREATE TABLE IF NOT EXISTS accounts ( 
    mt5_id      BIGINT          NOT NULL,       -- MT5 ACCOUNT_LOGIN ID --
    mt5_server  VARCHAR(64),
    available   BOOLEAN         NOT NULL DEFAULT FALSE,
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    account_id  BIGSERIAL       PRIMARY KEY,    -- ~(mt5_id, mt5_server) database create and map ea to connect server
    user_id     BIGINT          NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE (mt5_id, mt5_server) 
);


-- ========================================================================================================
-- Create indexes
-- ========================================================================================================
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);


-- ========================================================================================================
-- updated_at auto-update trigger
-- ========================================================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_users_set_updated_at'
  ) THEN
    EXECUTE $q$
      CREATE TRIGGER trg_users_set_updated_at
      BEFORE UPDATE ON users
      FOR EACH ROW
      EXECUTE FUNCTION public.set_updated_at()
    $q$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_accounts_set_updated_at'
  ) THEN
    EXECUTE $q$
      CREATE TRIGGER trg_accounts_set_updated_at
      BEFORE UPDATE ON accounts
      FOR EACH ROW
      EXECUTE FUNCTION public.set_updated_at()
    $q$;
  END IF;
END;
$$;