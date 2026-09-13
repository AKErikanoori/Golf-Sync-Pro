-- =================================================================================
-- GOLFSYNC PRO - ENTERPRISE TIER A DATABASE SCHEMA (SINGLE SOURCE OF TRUTH)
-- Standard: AGENTS.md / SOP Perusahaan v1.1
-- Engine: PostgreSQL 15+ (Supabase / AWS RDS / Self-Hosted)
-- =================================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =================================================================================
-- 2. TATA KELOLA PENGGUNA & PROFIL (USER MANAGEMENT)
-- =================================================================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email           VARCHAR(255) NULL,
    full_name       VARCHAR(255) NULL,
    avatar_url      TEXT NULL,
    handicap_index  NUMERIC(4, 1) NOT NULL DEFAULT 0.0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_premium      BOOLEAN NOT NULL DEFAULT FALSE,
    personal        JSONB NOT NULL DEFAULT '{"handicap":0,"history":[],"driving":[],"linkedPlayers":{},"recentTournaments":[]}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Pastikan kolom baru terpasang jika tabel sudah pernah dibuat sebelumnya
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS full_name VARCHAR(255);
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS handicap_index NUMERIC(4, 1) DEFAULT 0.0;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- Sinkronisasi email dan handicap untuk user eksisting
UPDATE public.user_profiles 
SET email = 'alfin.armadani@sugity.co.id', full_name = 'Alfin Armadani', handicap_index = 23.3, is_premium = TRUE 
WHERE id = '6f607902-a97a-46ae-858d-9dacc2c5a824' AND email IS NULL;

UPDATE public.user_profiles 
SET email = '4lfin.armadani@gmail.com', full_name = 'Alfin Armadani', handicap_index = 24.4, is_premium = TRUE 
WHERE id = '0a415328-32a3-482f-bed4-0d172f49776e' AND email IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_active ON public.user_profiles(is_active);

-- =================================================================================
-- 3. ROLE-BASED ACCESS CONTROL (DYNAMIC RBAC - POIN 8a & 9 SOP)
-- =================================================================================
CREATE TABLE IF NOT EXISTS public.roles (
    id              VARCHAR(50) PRIMARY KEY, -- 'super-admin', 'host', 'player'
    name            VARCHAR(100) NOT NULL,
    description     TEXT NULL,
    is_system       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.permissions (
    id              VARCHAR(100) PRIMARY KEY, -- e.g. 'users:manage', 'audit:view', 'config:edit', 'tour:host'
    name            VARCHAR(150) NOT NULL,
    module          VARCHAR(50) NOT NULL,
    description     TEXT NULL
);

CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id         VARCHAR(50) REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id   VARCHAR(100) REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id         UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    role_id         VARCHAR(50) REFERENCES public.roles(id) ON DELETE CASCADE,
    assigned_by     UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_role ON public.user_roles(role_id);

-- =================================================================================
-- 4. GLOBAL AUDIT LOGS (POIN 11 SOP)
-- =================================================================================
CREATE TABLE IF NOT EXISTS public.global_audit_logs (
    id              BIGSERIAL PRIMARY KEY,
    method          VARCHAR(10) NOT NULL, -- e.g. 'GET', 'POST', 'PUT', 'DELETE', 'AUTH', 'MUTATION'
    status_code     INT NOT NULL DEFAULT 200,
    endpoint_path   VARCHAR(255) NOT NULL,
    user_id         UUID NULL REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    user_role       VARCHAR(50) NULL,
    ip_address      VARCHAR(45) NOT NULL DEFAULT '0.0.0.0',
    duration_ms     INT NOT NULL DEFAULT 0,
    action_name     VARCHAR(100) NULL,
    payload_summary TEXT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_global_audit_created ON public.global_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_global_audit_user ON public.global_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_global_audit_path ON public.global_audit_logs(endpoint_path);

-- =================================================================================
-- 5. SITE CONFIGURATION (POIN 8a SOP - PARAMETER TANPA REDEPLOY)
-- =================================================================================
CREATE TABLE IF NOT EXISTS public.site_configurations (
    config_key      VARCHAR(100) PRIMARY KEY,
    config_value    TEXT NOT NULL,
    data_type       VARCHAR(20) NOT NULL DEFAULT 'string', -- 'string', 'number', 'boolean', 'json'
    description     TEXT NULL,
    is_public       BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by      UUID NULL REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================================
-- 6. BISNIS: SHARED TOURNAMENTS & SCORES
-- =================================================================================
CREATE TABLE IF NOT EXISTS public.shared_tournaments (
    code            VARCHAR(10) PRIMARY KEY, -- Room Code (e.g. 'ABCD')
    creator_id      UUID NULL REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    config          JSONB NOT NULL DEFAULT '{}'::jsonb,
    players         JSONB NOT NULL DEFAULT '[]'::jsonb,
    scores          JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_closed       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_shared_tournaments_creator ON public.shared_tournaments(creator_id);
CREATE INDEX IF NOT EXISTS idx_shared_tournaments_created ON public.shared_tournaments(created_at DESC);

-- =================================================================================
-- 7. HELPER FUNCTIONS & TRIGGERS
-- =================================================================================

-- Otomatis update kolom updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_shared_tournaments_updated_at
    BEFORE UPDATE ON public.shared_tournaments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Otomatis buat user_profile ketika user baru register di auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_role VARCHAR(50) := 'player';
BEGIN
    -- Jika email terdaftar sebagai admin utama, beri super-admin
    IF NEW.email IN ('alfin.armadani@sugity.co.id', '4lfin.armadani@gmail.com') THEN
        default_role := 'super-admin';
    END IF;

    INSERT INTO public.user_profiles (id, email, full_name, avatar_url, is_active, is_premium)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url',
        TRUE,
        (default_role = 'super-admin')
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        updated_at = CURRENT_TIMESTAMP;

    -- Assign role
    INSERT INTO public.user_roles (user_id, role_id)
    VALUES (NEW.id, default_role)
    ON CONFLICT DO NOTHING;

    -- Catat log pendaftaran
    INSERT INTO public.global_audit_logs (method, status_code, endpoint_path, user_id, user_role, action_name, payload_summary)
    VALUES ('AUTH', 201, '/auth/register', NEW.id, default_role, 'USER_REGISTERED', 'Registrasi user baru: ' || NEW.email);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger trigger_new_auth_user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Fungsi cek apakah user adalah super-admin
CREATE OR REPLACE FUNCTION public.is_super_admin(uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = uid AND role_id = 'super-admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- =================================================================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.global_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_tournaments ENABLE ROW LEVEL SECURITY;

-- 8.1. user_profiles RLS
CREATE POLICY "Users can view active profiles"
    ON public.user_profiles FOR SELECT
    USING (is_active = true OR auth.uid() = id OR public.is_super_admin(auth.uid()));

CREATE POLICY "Users can update their own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id OR public.is_super_admin(auth.uid()));

CREATE POLICY "Super admin can do everything on profiles"
    ON public.user_profiles FOR ALL
    USING (public.is_super_admin(auth.uid()));

-- 8.2. site_configurations RLS
CREATE POLICY "Public can view public site configs"
    ON public.site_configurations FOR SELECT
    USING (is_public = true OR public.is_super_admin(auth.uid()));

CREATE POLICY "Super admin can manage site configs"
    ON public.site_configurations FOR ALL
    USING (public.is_super_admin(auth.uid()));

-- 8.3. global_audit_logs RLS
CREATE POLICY "Super admin can view audit logs"
    ON public.global_audit_logs FOR SELECT
    USING (public.is_super_admin(auth.uid()));

CREATE POLICY "Authenticated users can insert audit logs"
    ON public.global_audit_logs FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- 8.4. RBAC tables RLS
CREATE POLICY "Anyone authenticated can view roles"
    ON public.roles FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Super admin can manage roles"
    ON public.roles FOR ALL USING (public.is_super_admin(auth.uid()));

CREATE POLICY "Anyone authenticated can view user roles"
    ON public.user_roles FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Super admin can manage user roles"
    ON public.user_roles FOR ALL USING (public.is_super_admin(auth.uid()));

-- 8.5. shared_tournaments RLS
CREATE POLICY "Anyone can view shared tournaments by code"
    ON public.shared_tournaments FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create tournaments"
    ON public.shared_tournaments FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Creator or host or super admin can update tournaments"
    ON public.shared_tournaments FOR UPDATE
    USING (
        auth.uid() = creator_id 
        OR public.is_super_admin(auth.uid()) 
        OR EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role_id IN ('host', 'super-admin'))
    );

CREATE POLICY "Creator or super admin can delete tournaments"
    ON public.shared_tournaments FOR DELETE
    USING (auth.uid() = creator_id OR public.is_super_admin(auth.uid()));

-- =================================================================================
-- 9. INITIAL SEED DATA (FONDASI WAJIB TIER A)
-- =================================================================================

-- 9.1. Roles
INSERT INTO public.roles (id, name, description, is_system) VALUES
('super-admin', 'Super Administrator', 'Akses penuh ke User Management, Audit Logs, Site Config, dan RBAC', TRUE),
('host', 'Tournament Host', 'Dapat membuat room turnamen, mengatur pemain, dan format pertandingan', TRUE),
('player', 'Regular Player', 'Dapat bergabung ke turnamen, mencatat ronde personal, dan driving', TRUE)
ON CONFLICT (id) DO NOTHING;

-- 9.2. Permissions
INSERT INTO public.permissions (id, name, module, description) VALUES
('users:create', 'Create User', 'users', 'Mendaftarkan user baru ke sistem'),
('users:read', 'Read Users', 'users', 'Melihat daftar dan profil user'),
('users:update', 'Update User', 'users', 'Memperbarui profil, status aktif, dan role user'),
('users:delete', 'Delete User', 'users', 'Menghapus atau menonaktifkan akun user'),
('audit:read', 'Read Audit Logs', 'audit', 'Melihat riwayat global audit logs'),
('config:read', 'Read Site Config', 'config', 'Melihat parameter konfigurasi situs'),
('config:update', 'Update Site Config', 'config', 'Mengubah parameter konfigurasi situs tanpa redeploy'),
('rbac:manage', 'Manage RBAC', 'rbac', 'Mengatur hak akses dan penugasan role'),
('tour:create', 'Create Tournament', 'tour', 'Membuat room turnamen baru'),
('tour:score', 'Record Score', 'tour', 'Memasukkan skor pertandingan')
ON CONFLICT (id) DO NOTHING;

-- 9.3. Role Permissions Mapping
-- Super-Admin gets all permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 'super-admin', id FROM public.permissions
ON CONFLICT DO NOTHING;

-- Host permissions
INSERT INTO public.role_permissions (role_id, permission_id) VALUES
('host', 'tour:create'),
('host', 'tour:score'),
('host', 'users:read'),
('host', 'config:read')
ON CONFLICT DO NOTHING;

-- Player permissions
INSERT INTO public.role_permissions (role_id, permission_id) VALUES
('player', 'tour:score'),
('player', 'config:read')
ON CONFLICT DO NOTHING;

-- 9.4. Site Configurations Default
INSERT INTO public.site_configurations (config_key, config_value, data_type, description, is_public) VALUES
('APP_NAME', 'GolfSync PRO', 'string', 'Nama resmi aplikasi', TRUE),
('MAINTENANCE_MODE', 'false', 'boolean', 'Status mode pemeliharaan sistem', TRUE),
('MAX_PLAYERS_PER_ROOM', '24', 'number', 'Batas maksimal pemain dalam satu room turnamen', TRUE),
('DEFAULT_COURSE_PAR', '72', 'number', 'Standar default total par lapangan golf', TRUE),
('AUDIT_LOG_RETENTION_DAYS', '90', 'number', 'Masa simpan log audit sebelum diarsipkan', FALSE),
('ALLOW_REGISTRATION', 'true', 'boolean', 'Izinkan pendaftaran akun baru secara mandiri', TRUE)
ON CONFLICT (config_key) DO NOTHING;

-- 9.5. Penugasan Role Super-Admin untuk Admin Eksisting
INSERT INTO public.user_roles (user_id, role_id) VALUES
('6f607902-a97a-46ae-858d-9dacc2c5a824', 'super-admin'),
('0a415328-32a3-482f-bed4-0d172f49776e', 'super-admin')
ON CONFLICT (user_id, role_id) DO NOTHING;

