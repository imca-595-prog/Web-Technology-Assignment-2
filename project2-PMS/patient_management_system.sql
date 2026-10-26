-- ============================================================
-- Patient Management System - Database Setup Script
-- ============================================================
-- Instructions:
--   1. Open MySQL Workbench or phpMyAdmin.
--   2. Run this entire script to create the database and tables.
--   3. Sample departments and doctors will be inserted automatically.
-- ============================================================

-- Step 1: Create the database
CREATE DATABASE IF NOT EXISTS patient_management_system;

-- Step 2: Select the database
USE patient_management_system;

-- ============================================================
-- Table 1: patients
-- Stores patient account information.
-- NOTE: Passwords are stored as plain text here for the
--       college demonstration ONLY.
--       In a real application, always use password hashing
--       (e.g., BCrypt) before storing passwords.
-- ============================================================
CREATE TABLE IF NOT EXISTS patients (
    patient_id    INT          PRIMARY KEY AUTO_INCREMENT,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    date_of_birth DATE         NOT NULL,
    gender        VARCHAR(20)  NOT NULL,
    blood_group   VARCHAR(5)   NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    address       VARCHAR(255) NOT NULL,
    phone         VARCHAR(15)  NOT NULL UNIQUE,
    password      VARCHAR(255) NOT NULL
);

-- ============================================================
-- Table 2: departments
-- Stores hospital department names.
-- ============================================================
CREATE TABLE IF NOT EXISTS departments (
    department_id   INT          PRIMARY KEY AUTO_INCREMENT,
    department_name VARCHAR(100) NOT NULL UNIQUE
);

-- ============================================================
-- Table 3: doctors
-- Stores doctor information.
-- NOTE: No doctor_id or department_id columns as specified.
--       The department_name column links a doctor to a department
--       by matching the name in the departments table.
-- ============================================================
CREATE TABLE IF NOT EXISTS doctors (
    doctor_name     VARCHAR(100) NOT NULL,
    specialization  VARCHAR(100) NOT NULL,
    phone           VARCHAR(15),
    department_name VARCHAR(100) NOT NULL
);

-- ============================================================
-- Table 4: appointments
-- Stores appointment details.
--
-- *** IMPORTANT LIMITATION (documented as required) ***
-- This table has NO appointment_id and NO patient_id column
-- as specified in the project requirements.
-- This means:
--   (a) Individual appointments cannot be uniquely identified.
--   (b) Appointments cannot be securely linked to the patient
--       who booked them without an extra workaround.
--   (c) If two appointments share the same department, doctor,
--       date, and time, they cannot be reliably distinguished.
-- Update and Delete operations in this demo use the combination
-- of all appointment fields + the logged-in patient phone as a
-- best-effort approach, but this is NOT production-safe.
-- In a real application, always add appointment_id (PK) and
-- patient_id (FK) to the appointments table.
--
-- We add patient_phone as a minimal workaround to associate
-- appointments with patients without adding a patient_id FK.
-- ============================================================
CREATE TABLE IF NOT EXISTS appointments (
    department_name    VARCHAR(100) NOT NULL,
    doctor_name        VARCHAR(100) NOT NULL,
    appointment_date   DATE         NOT NULL,
    appointment_time   TIME         NOT NULL,
    reason_for_visit   VARCHAR(255) NOT NULL,
    appointment_status VARCHAR(30)  DEFAULT 'Booked',
    patient_phone      VARCHAR(15)  NOT NULL
);

-- ============================================================
-- Sample Data: Departments
-- ============================================================
INSERT INTO departments (department_name) VALUES
    ('Cardiology'),
    ('Neurology'),
    ('Orthopedics'),
    ('Dermatology'),
    ('Pediatrics'),
    ('General Medicine'),
    ('ENT'),
    ('Ophthalmology');

-- ============================================================
-- Sample Data: Doctors
-- (department_name must exactly match values in departments table)
-- ============================================================

-- Cardiology
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Arjun Sharma',    'Interventional Cardiologist',  '9876500001', 'Cardiology'),
    ('Dr. Priya Mehta',     'Cardiac Electrophysiologist',  '9876500002', 'Cardiology'),
    ('Dr. Ravi Nair',       'Heart Failure Specialist',     '9876500003', 'Cardiology');

-- Neurology
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Sunita Rao',      'Clinical Neurologist',         '9876500004', 'Neurology'),
    ('Dr. Kiran Joshi',     'Epilepsy Specialist',          '9876500005', 'Neurology'),
    ('Dr. Amit Verma',      'Stroke Specialist',            '9876500006', 'Neurology');

-- Orthopedics
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Deepak Gupta',    'Joint Replacement Surgeon',    '9876500007', 'Orthopedics'),
    ('Dr. Neha Kulkarni',   'Sports Medicine Specialist',   '9876500008', 'Orthopedics'),
    ('Dr. Suresh Patil',    'Spine Surgeon',                '9876500009', 'Orthopedics');

-- Dermatology
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Ananya Singh',    'Cosmetic Dermatologist',       '9876500010', 'Dermatology'),
    ('Dr. Rohit Kapoor',    'Pediatric Dermatologist',      '9876500011', 'Dermatology'),
    ('Dr. Meena Iyer',      'Dermatopathologist',           '9876500012', 'Dermatology');

-- Pediatrics
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Kavita Reddy',    'Neonatologist',                '9876500013', 'Pediatrics'),
    ('Dr. Vijay Pillai',    'Pediatric Cardiologist',       '9876500014', 'Pediatrics'),
    ('Dr. Lakshmi Devi',    'General Pediatrician',         '9876500015', 'Pediatrics');

-- General Medicine
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Manish Tiwari',   'General Physician',            '9876500016', 'General Medicine'),
    ('Dr. Pooja Saxena',    'Internal Medicine Specialist', '9876500017', 'General Medicine'),
    ('Dr. Harish Kumar',    'Family Medicine Doctor',       '9876500018', 'General Medicine');

-- ENT
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Sanjay Bhat',     'Rhinologist',                  '9876500019', 'ENT'),
    ('Dr. Rekha Nambiar',   'Otologist',                    '9876500020', 'ENT'),
    ('Dr. Prakash Menon',   'Head and Neck Surgeon',        '9876500021', 'ENT');

-- Ophthalmology
INSERT INTO doctors (doctor_name, specialization, phone, department_name) VALUES
    ('Dr. Geetha Krishnan', 'Retinal Specialist',           '9876500022', 'Ophthalmology'),
    ('Dr. Anil Desai',      'Glaucoma Specialist',          '9876500023', 'Ophthalmology'),
    ('Dr. Smita Patel',     'Cornea Specialist',            '9876500024', 'Ophthalmology');

-- ============================================================
-- End of Setup Script
-- ============================================================
