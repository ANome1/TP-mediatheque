-- =====================================================================
--  Médiathèque municipale — schéma de la base
--  Module SQL avancé · B2 Informatique · Lionel Duport
--  SGBD : MySQL 8 (compatible MariaDB 10.5+)
--
--  À exécuter avec un compte administrateur :
--      mysql -u root -p < base-01-schema.sql
-- =====================================================================

DROP DATABASE IF EXISTS mediatheque;
CREATE DATABASE mediatheque
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE mediatheque;

-- ---------------------------------------------------------------------
--  Référentiel
-- ---------------------------------------------------------------------
CREATE TABLE categorie (
  id       TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  libelle  VARCHAR(60)      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categorie_libelle (libelle)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
--  Adhérents
--  Les colonnes email, telephone et date_naissance sont des données
--  personnelles : elles servent de terrain d'exercice au DCL (séance 1)
--  et aux vues de masquage (séance 2).
-- ---------------------------------------------------------------------
CREATE TABLE adherent (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nom               VARCHAR(60)  NOT NULL,
  prenom            VARCHAR(60)  NOT NULL,
  email             VARCHAR(120) NOT NULL,
  telephone         VARCHAR(20)      NULL,
  date_naissance    DATE             NULL,
  ville             VARCHAR(60)  NOT NULL,
  date_inscription  DATE         NOT NULL,
  actif             TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_adherent_email (email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
--  Catalogue
--  ouvrage    = l'œuvre (un titre, un auteur)
--  exemplaire = l'objet physique que l'on emprunte (un code-barres)
-- ---------------------------------------------------------------------
CREATE TABLE ouvrage (
  id                 INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  titre              VARCHAR(160)     NOT NULL,
  auteur             VARCHAR(120)     NOT NULL,
  isbn               CHAR(13)             NULL,
  annee_publication  SMALLINT UNSIGNED    NULL,
  editeur            VARCHAR(80)          NULL,
  categorie_id       TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ouvrage_isbn (isbn),
  CONSTRAINT fk_ouvrage_categorie
    FOREIGN KEY (categorie_id) REFERENCES categorie (id)
) ENGINE=InnoDB;

CREATE TABLE exemplaire (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  ouvrage_id        INT UNSIGNED NOT NULL,
  code_barre        VARCHAR(20)  NOT NULL,
  etat              ENUM('neuf','bon','use','hors_service') NOT NULL DEFAULT 'bon',
  disponible        TINYINT(1)   NOT NULL DEFAULT 1,
  date_acquisition  DATE         NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_exemplaire_code_barre (code_barre),
  CONSTRAINT fk_exemplaire_ouvrage
    FOREIGN KEY (ouvrage_id) REFERENCES ouvrage (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
--  Circulation
--  date_retour_reelle NULL  =  l'exemplaire est encore chez l'adhérent
-- ---------------------------------------------------------------------
CREATE TABLE emprunt (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  exemplaire_id       INT UNSIGNED NOT NULL,
  adherent_id         INT UNSIGNED NOT NULL,
  date_emprunt        DATE         NOT NULL,
  date_retour_prevue  DATE         NOT NULL,
  date_retour_reelle  DATE             NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_emprunt_exemplaire
    FOREIGN KEY (exemplaire_id) REFERENCES exemplaire (id),
  CONSTRAINT fk_emprunt_adherent
    FOREIGN KEY (adherent_id) REFERENCES adherent (id)
) ENGINE=InnoDB;

CREATE TABLE reservation (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  ouvrage_id         INT UNSIGNED NOT NULL,
  adherent_id        INT UNSIGNED NOT NULL,
  date_reservation   DATE         NOT NULL,
  statut             ENUM('en_attente','satisfaite','annulee') NOT NULL DEFAULT 'en_attente',
  PRIMARY KEY (id),
  CONSTRAINT fk_reservation_ouvrage
    FOREIGN KEY (ouvrage_id) REFERENCES ouvrage (id),
  CONSTRAINT fk_reservation_adherent
    FOREIGN KEY (adherent_id) REFERENCES adherent (id)
) ENGINE=InnoDB;

CREATE TABLE penalite (
  id             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  adherent_id    INT UNSIGNED  NOT NULL,
  emprunt_id     INT UNSIGNED      NULL,
  montant        DECIMAL(6,2)  NOT NULL,
  motif          VARCHAR(120)  NOT NULL,
  date_creation  DATE          NOT NULL,
  payee          TINYINT(1)    NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  CONSTRAINT fk_penalite_adherent
    FOREIGN KEY (adherent_id) REFERENCES adherent (id),
  CONSTRAINT fk_penalite_emprunt
    FOREIGN KEY (emprunt_id) REFERENCES emprunt (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
--  Volontairement : aucun index secondaire.
--  Les seuls index présents sont ceux que MySQL crée tout seul
--  (clés primaires, contraintes UNIQUE, clés étrangères).
--  Les index utiles, c'est vous qui les poserez en séance 2.
-- ---------------------------------------------------------------------

SELECT 'Schéma mediatheque créé.' AS resultat;
