BEGIN;

-- =========================================================
-- EXTENSIONS
-- =========================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- =========================================================
-- FONCTION updated_at
-- =========================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- TABLE: roles
-- =========================================================
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    label VARCHAR(100) NOT NULL
);

-- =========================================================
-- TABLE: users
-- =========================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id INT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email CITEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    phone VARCHAR(30),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: pages
-- =========================================================
CREATE TABLE pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(150) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    meta_title VARCHAR(255),
    meta_description TEXT,
    hero_title VARCHAR(255),
    hero_subtitle TEXT,
    body JSONB,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: services
-- =========================================================
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(150) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    short_description TEXT,
    long_description TEXT,
    icon VARCHAR(100),
    cover_image_url TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: media
-- =========================================================
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name VARCHAR(255) NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size BIGINT NOT NULL CHECK (file_size >= 0),
    storage_provider VARCHAR(50) NOT NULL DEFAULT 'local',
    storage_path TEXT NOT NULL,
    public_url TEXT,
    alt_text VARCHAR(255),
    width INT CHECK (width IS NULL OR width > 0),
    height INT CHECK (height IS NULL OR height > 0),
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: gallery_items
-- =========================================================
CREATE TABLE gallery_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255),
    description TEXT,
    category VARCHAR(100),
    cover_media_id UUID REFERENCES media(id) ON DELETE SET NULL,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: before_after_items
-- =========================================================
CREATE TABLE before_after_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255),
    description TEXT,
    service_id UUID REFERENCES services(id) ON DELETE SET NULL,
    before_media_id UUID NOT NULL REFERENCES media(id) ON DELETE RESTRICT,
    after_media_id UUID NOT NULL REFERENCES media(id) ON DELETE RESTRICT,
    vehicle_brand VARCHAR(100),
    vehicle_model VARCHAR(100),
    vehicle_color VARCHAR(100),
    vehicle_year VARCHAR(20),
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_before_after_different_media
        CHECK (before_media_id <> after_media_id)
);

-- =========================================================
-- TABLE: partners
-- =========================================================
CREATE TABLE partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    website_url TEXT,
    logo_media_id UUID REFERENCES media(id) ON DELETE SET NULL,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: google_reviews
-- =========================================================
CREATE TABLE google_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_review_id VARCHAR(255) NOT NULL UNIQUE,
    author_name VARCHAR(255) NOT NULL,
    author_profile_url TEXT,
    author_photo_url TEXT,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    review_date TIMESTAMPTZ,
    relative_time_description VARCHAR(100),
    source VARCHAR(50) NOT NULL DEFAULT 'google',
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: google_review_sync_logs
-- =========================================================
CREATE TABLE google_review_sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status VARCHAR(30) NOT NULL,
    reviews_fetched_count INT NOT NULL DEFAULT 0,
    message TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    CONSTRAINT chk_google_review_sync_status
        CHECK (status IN ('started', 'success', 'partial', 'failed'))
);

-- =========================================================
-- TABLE: quote_requests
-- =========================================================
CREATE TABLE quote_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email CITEXT,
    phone VARCHAR(30) NOT NULL,
    vehicle_brand VARCHAR(100),
    vehicle_model VARCHAR(100),
    vehicle_year VARCHAR(20),
    registration_number VARCHAR(30),
    damage_type VARCHAR(100),
    message TEXT,
    preferred_contact_method VARCHAR(20),
    status VARCHAR(30) NOT NULL DEFAULT 'new',
    source VARCHAR(50) NOT NULL DEFAULT 'website',
    consent_privacy BOOLEAN NOT NULL DEFAULT FALSE,
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_quote_status
        CHECK (status IN ('new', 'in_progress', 'contacted', 'quoted', 'closed', 'archived')),
    CONSTRAINT chk_preferred_contact_method
        CHECK (
            preferred_contact_method IS NULL
            OR preferred_contact_method IN ('phone', 'email', 'sms')
        )
);

-- =========================================================
-- TABLE: quote_request_photos
-- =========================================================
CREATE TABLE quote_request_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_request_id UUID NOT NULL REFERENCES quote_requests(id) ON DELETE CASCADE,
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_quote_request_photo UNIQUE (quote_request_id, media_id)
);

-- =========================================================
-- TABLE: testimonials
-- =========================================================
CREATE TABLE testimonials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_name VARCHAR(255) NOT NULL,
    author_role VARCHAR(255),
    content TEXT NOT NULL,
    rating SMALLINT CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    avatar_media_id UUID REFERENCES media(id) ON DELETE SET NULL,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: site_settings
-- =========================================================
CREATE TABLE site_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(150) NOT NULL UNIQUE,
    setting_value JSONB NOT NULL,
    description TEXT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: faq_items
-- =========================================================
CREATE TABLE faq_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- TABLE: contact_messages
-- =========================================================
CREATE TABLE contact_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(200) NOT NULL,
    email CITEXT,
    phone VARCHAR(30),
    subject VARCHAR(255),
    message TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_contact_message_status
        CHECK (status IN ('new', 'read', 'replied', 'archived'))
);

-- =========================================================
-- TABLE: admin_audit_logs
-- =========================================================
CREATE TABLE admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- INDEXES
-- =========================================================
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_is_active ON users(is_active);

CREATE INDEX idx_pages_slug ON pages(slug);
CREATE INDEX idx_pages_is_published ON pages(is_published);

CREATE INDEX idx_services_slug ON services(slug);
CREATE INDEX idx_services_is_active ON services(is_active);
CREATE INDEX idx_services_sort_order ON services(sort_order);

CREATE INDEX idx_media_uploaded_by ON media(uploaded_by);

CREATE INDEX idx_gallery_items_category ON gallery_items(category);
CREATE INDEX idx_gallery_items_is_published ON gallery_items(is_published);
CREATE INDEX idx_gallery_items_sort_order ON gallery_items(sort_order);

CREATE INDEX idx_before_after_service_id ON before_after_items(service_id);
CREATE INDEX idx_before_after_is_published ON before_after_items(is_published);
CREATE INDEX idx_before_after_sort_order ON before_after_items(sort_order);

CREATE INDEX idx_partners_is_active ON partners(is_active);
CREATE INDEX idx_partners_sort_order ON partners(sort_order);

CREATE INDEX idx_google_reviews_review_date ON google_reviews(review_date DESC);
CREATE INDEX idx_google_reviews_is_published ON google_reviews(is_published);
CREATE INDEX idx_google_reviews_pub_date ON google_reviews(is_published, review_date DESC);

CREATE INDEX idx_quote_requests_status ON quote_requests(status);
CREATE INDEX idx_quote_requests_created_at ON quote_requests(created_at DESC);
CREATE INDEX idx_quote_requests_assigned_to ON quote_requests(assigned_to);

CREATE INDEX idx_quote_request_photos_quote_request_id ON quote_request_photos(quote_request_id);
CREATE INDEX idx_quote_request_photos_media_id ON quote_request_photos(media_id);

CREATE INDEX idx_testimonials_is_published ON testimonials(is_published);
CREATE INDEX idx_testimonials_sort_order ON testimonials(sort_order);

CREATE INDEX idx_site_settings_updated_by ON site_settings(updated_by);

CREATE INDEX idx_faq_items_is_published ON faq_items(is_published);
CREATE INDEX idx_faq_items_sort_order ON faq_items(sort_order);

CREATE INDEX idx_contact_messages_status ON contact_messages(status);
CREATE INDEX idx_contact_messages_created_at ON contact_messages(created_at DESC);

CREATE INDEX idx_admin_audit_logs_user_id ON admin_audit_logs(user_id);
CREATE INDEX idx_admin_audit_logs_entity_type ON admin_audit_logs(entity_type);
CREATE INDEX idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);

-- =========================================================
-- TRIGGERS updated_at
-- =========================================================
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pages_updated_at
BEFORE UPDATE ON pages
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_services_updated_at
BEFORE UPDATE ON services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gallery_items_updated_at
BEFORE UPDATE ON gallery_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_before_after_items_updated_at
BEFORE UPDATE ON before_after_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_partners_updated_at
BEFORE UPDATE ON partners
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_google_reviews_updated_at
BEFORE UPDATE ON google_reviews
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_quote_requests_updated_at
BEFORE UPDATE ON quote_requests
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_testimonials_updated_at
BEFORE UPDATE ON testimonials
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_site_settings_updated_at
BEFORE UPDATE ON site_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_faq_items_updated_at
BEFORE UPDATE ON faq_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_messages_updated_at
BEFORE UPDATE ON contact_messages
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- SEED: roles
-- =========================================================
INSERT INTO roles (code, label)
VALUES
    ('super_admin', 'Super administrateur'),
    ('admin', 'Administrateur'),
    ('editor', 'Éditeur'),
    ('agent', 'Agent')
ON CONFLICT (code) DO NOTHING;

-- =========================================================
-- SEED: site_settings
-- =========================================================
INSERT INTO site_settings (setting_key, setting_value, description)
VALUES
    ('company.name', '"AutoPaintExpress"', 'Nom de l’entreprise'),
    ('company.phone', '"0628109758"', 'Téléphone principal'),
    ('company.email', '"contact@autopaintexpress.fr"', 'Email principal'),
    ('company.address', '"France"', 'Adresse principale'),
    ('company.hours', '{"monday":"08:00-18:00","tuesday":"08:00-18:00","wednesday":"08:00-18:00","thursday":"08:00-18:00","friday":"08:00-18:00"}', 'Horaires d’ouverture'),
    ('social.links', '{"facebook":null,"instagram":null,"tiktok":null}', 'Liens réseaux sociaux')
ON CONFLICT (setting_key) DO NOTHING;

COMMIT;