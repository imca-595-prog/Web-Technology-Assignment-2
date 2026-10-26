<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="java.util.Date" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.LinkedHashMap" %>
<%!
    // ============================================================
    // DATABASE CONNECTION (defined directly in this JSP)
    // Change the three values below to match your MySQL setup:
    //   DB_URL      - jdbc:mysql://HOST:PORT/DATABASE_NAME
    //   DB_USER     - your MySQL username (usually "root")
    //   DB_PASSWORD - your MySQL password
    // The JDBC driver jar must be in WEB-INF/lib/
    // ============================================================
    private static final String DB_URL =
        "jdbc:mysql://localhost:3307/patient_management_system"
        + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "root";

    /** Returns an open MySQL database connection. */
    public java.sql.Connection getConnection() throws java.sql.SQLException {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new java.sql.SQLException(
                "MySQL JDBC Driver not found. Add mysql-connector-j jar to WEB-INF/lib/", e);
        }
        return java.sql.DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    }

    /** Escapes special HTML characters to prevent XSS. */
    public String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    /** Reads a request parameter, trimmed; never returns null. */
    public String param(jakarta.servlet.http.HttpServletRequest request, String name) {
        String v = request.getParameter(name);
        return v == null ? "" : v.trim();
    }

    /** Escapes a string for use inside a JSON string value. */
    public String jsonEsc(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    public void closeQuietly(AutoCloseable c) {
        if (c != null) {
            try { c.close(); } catch (Exception ignore) { }
        }
    }
%>
<%--
    patient_management_system.jsp
    Single JSP that handles ALL server-side operations:
    registration, login/logout, session check, dashboard, doctor list (JSON),
    and appointment booking / listing / update / delete.

    NOTE ON SCHEMA LIMITATION: the appointments table has no appointment_id and
    no patient_id, so patient_phone is used to link appointments to a patient.
    Identical appointments cannot be told apart. Demo only - not production safe.
--%>
<%
    // ================================================================
    // STEP 1 - Determine which action is being requested
    // ================================================================
    String action = request.getParameter("action");
    if (action == null) action = "";
    boolean isPost = "POST".equals(request.getMethod());

    // ================================================================
    // STEP 2 - "doctors" AJAX request: return pure JSON and stop
    // ================================================================
    if ("doctors".equals(action)) {
        String deptName = param(request, "department");
        response.setContentType("application/json; charset=UTF-8");
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");

        if (deptName.isEmpty()) {
            out.print("[]");
            return;
        }

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            conn = getConnection();
            ps = conn.prepareStatement(
                "SELECT doctor_name, specialization FROM doctors WHERE department_name = ? ORDER BY doctor_name");
            ps.setString(1, deptName);
            rs = ps.executeQuery();

            StringBuilder sb = new StringBuilder("[");
            boolean first = true;
            while (rs.next()) {
                if (!first) sb.append(",");
                sb.append("{\"name\":\"").append(jsonEsc(rs.getString("doctor_name")))
                  .append("\",\"spec\":\"").append(jsonEsc(rs.getString("specialization")))
                  .append("\"}");
                first = false;
            }
            sb.append("]");
            out.print(sb.toString());
        } catch (SQLException e) {
            out.print("[]");
        } finally {
            closeQuietly(rs);
            closeQuietly(ps);
            closeQuietly(conn);
        }
        return;
    }

    // ================================================================
    // STEP 3 - REGISTRATION (POST)
    // ================================================================
    if ("register".equals(action) && isPost) {
        request.setCharacterEncoding("UTF-8");
        String firstName = param(request, "first_name");
        String lastName  = param(request, "last_name");
        String dob       = param(request, "date_of_birth");
        String gender    = param(request, "gender");
        String bloodGroup = param(request, "blood_group");
        String email     = param(request, "email");
        String address   = param(request, "address");
        String phone     = param(request, "phone");
        String password  = request.getParameter("password") != null ? request.getParameter("password") : "";

        if (firstName.isEmpty() || lastName.isEmpty() || dob.isEmpty() || gender.isEmpty()
                || bloodGroup.isEmpty() || email.isEmpty() || address.isEmpty()
                || phone.isEmpty() || password.isEmpty()
                || !phone.matches("\\d{10,15}") || password.length() < 6) {
            response.sendRedirect("patient_management_system.html?error=reg_failed&tab=register");
            return;
        }

        Connection conn = null;
        PreparedStatement checkPs = null;
        PreparedStatement insertPs = null;
        ResultSet checkRs = null;
        try {
            conn = getConnection();

            checkPs = conn.prepareStatement("SELECT patient_id FROM patients WHERE email = ?");
            checkPs.setString(1, email);
            checkRs = checkPs.executeQuery();
            if (checkRs.next()) {
                response.sendRedirect("patient_management_system.html?error=duplicate_email&tab=register");
                return;
            }
            checkRs.close();
            checkPs.close();

            checkPs = conn.prepareStatement("SELECT patient_id FROM patients WHERE phone = ?");
            checkPs.setString(1, phone);
            checkRs = checkPs.executeQuery();
            if (checkRs.next()) {
                response.sendRedirect("patient_management_system.html?error=duplicate_phone&tab=register");
                return;
            }

            // NOTE: plain-text password for this college demo only.
            insertPs = conn.prepareStatement(
                "INSERT INTO patients (first_name, last_name, date_of_birth, gender, blood_group, email, address, phone, password) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
            insertPs.setString(1, firstName);
            insertPs.setString(2, lastName);
            insertPs.setString(3, dob);
            insertPs.setString(4, gender);
            insertPs.setString(5, bloodGroup);
            insertPs.setString(6, email);
            insertPs.setString(7, address);
            insertPs.setString(8, phone);
            insertPs.setString(9, password);
            insertPs.executeUpdate();

            response.sendRedirect("patient_management_system.html?msg=registered");
        } catch (SQLException e) {
            response.sendRedirect("patient_management_system.html?error=reg_failed&tab=register");
        } finally {
            closeQuietly(checkRs);
            closeQuietly(checkPs);
            closeQuietly(insertPs);
            closeQuietly(conn);
        }
        return;
    }

    // ================================================================
    // STEP 4 - LOGIN (POST)
    // ================================================================
    if ("login".equals(action) && isPost) {
        String phone = param(request, "phone");
        String password = request.getParameter("password") != null ? request.getParameter("password") : "";

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            conn = getConnection();
            ps = conn.prepareStatement(
                "SELECT patient_id, first_name, last_name, phone, email, gender, blood_group, date_of_birth, address "
                + "FROM patients WHERE phone = ? AND password = ?");
            ps.setString(1, phone);
            ps.setString(2, password);
            rs = ps.executeQuery();

            if (rs.next()) {
                HttpSession sess = request.getSession(true);
                sess.setAttribute("patientId", rs.getInt("patient_id"));
                sess.setAttribute("firstName", rs.getString("first_name"));
                sess.setAttribute("lastName", rs.getString("last_name"));
                sess.setAttribute("phone", rs.getString("phone"));
                sess.setAttribute("email", rs.getString("email"));
                sess.setAttribute("gender", rs.getString("gender"));
                sess.setAttribute("bloodGroup", rs.getString("blood_group"));
                sess.setAttribute("dob", rs.getString("date_of_birth"));
                sess.setAttribute("address", rs.getString("address"));
                sess.setAttribute("loggedIn", Boolean.TRUE);
                response.sendRedirect("patient_management_system.jsp");
            } else {
                response.sendRedirect("patient_management_system.html?error=invalid_credentials");
            }
        } catch (SQLException e) {
            response.sendRedirect("patient_management_system.html?error=db_error");
        } finally {
            closeQuietly(rs);
            closeQuietly(ps);
            closeQuietly(conn);
        }
        return;
    }

    // ================================================================
    // STEP 5 - LOGOUT
    // ================================================================
    if ("logout".equals(action)) {
        HttpSession logoutSess = request.getSession(false);
        if (logoutSess != null) {
            logoutSess.invalidate();
        }
        response.sendRedirect("patient_management_system.html?msg=logged_out");
        return;
    }

    // ================================================================
    // STEP 6 - SESSION CHECK (dashboard requires login)
    // ================================================================
    HttpSession userSession = request.getSession(false);
    Boolean isLoggedIn = (userSession != null) ? (Boolean) userSession.getAttribute("loggedIn") : null;
    if (isLoggedIn == null || !isLoggedIn) {
        response.sendRedirect("patient_management_system.html");
        return;
    }

    String sessFirstName = (String) userSession.getAttribute("firstName");
    String sessLastName  = (String) userSession.getAttribute("lastName");
    String sessPhone     = (String) userSession.getAttribute("phone");
    String sessEmail     = (String) userSession.getAttribute("email");
    String sessGender    = (String) userSession.getAttribute("gender");
    String sessBloodGroup = (String) userSession.getAttribute("bloodGroup");
    String sessDob       = (String) userSession.getAttribute("dob");
    String sessAddress   = (String) userSession.getAttribute("address");

    // ================================================================
    // STEP 7 - BOOK APPOINTMENT (POST)
    // ================================================================
    String bookMessage = "";
    boolean bookSuccess = false;

    if ("book".equals(action) && isPost) {
        request.setCharacterEncoding("UTF-8");
        String deptName   = param(request, "department_name");
        String doctorName = param(request, "doctor_name");
        String apptDate   = param(request, "appointment_date");
        String apptTime   = param(request, "appointment_time");
        String reason     = param(request, "reason_for_visit");

        if (deptName.isEmpty() || doctorName.isEmpty() || apptDate.isEmpty()
                || apptTime.isEmpty() || reason.isEmpty()) {
            bookMessage = "❌ All appointment fields are required.";
        } else {
            try {
                SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
                Date selectedDate = sdf.parse(apptDate);
                if (selectedDate.before(sdf.parse(sdf.format(new Date())))) {
                    bookMessage = "❌ Appointment date cannot be in the past.";
                }
            } catch (Exception e) {
                bookMessage = "❌ Invalid appointment date format.";
            }
        }

        if (bookMessage.isEmpty()) {
            Connection conn = null;
            PreparedStatement checkPs = null;
            ResultSet checkRs = null;
            try {
                conn = getConnection();
                checkPs = conn.prepareStatement(
                    "SELECT doctor_name FROM doctors WHERE doctor_name = ? AND department_name = ?");
                checkPs.setString(1, doctorName);
                checkPs.setString(2, deptName);
                checkRs = checkPs.executeQuery();
                if (!checkRs.next()) {
                    bookMessage = "❌ The selected doctor does not belong to the selected department.";
                }
            } catch (SQLException e) {
                bookMessage = "❌ Database error during validation. Please try again.";
            } finally {
                closeQuietly(checkRs);
                closeQuietly(checkPs);
                closeQuietly(conn);
            }
        }

        if (bookMessage.isEmpty()) {
            Connection conn = null;
            PreparedStatement ps = null;
            try {
                conn = getConnection();
                ps = conn.prepareStatement(
                    "INSERT INTO appointments (department_name, doctor_name, appointment_date, appointment_time, reason_for_visit, appointment_status, patient_phone) "
                    + "VALUES (?, ?, ?, ?, ?, 'Booked', ?)");
                ps.setString(1, deptName);
                ps.setString(2, doctorName);
                ps.setString(3, apptDate);
                ps.setString(4, apptTime);
                ps.setString(5, reason);
                ps.setString(6, sessPhone);
                ps.executeUpdate();
                bookSuccess = true;
                bookMessage = "✅ Appointment booked successfully!";
            } catch (SQLException e) {
                bookMessage = "❌ Failed to book appointment. Please try again.";
            } finally {
                closeQuietly(ps);
                closeQuietly(conn);
            }
        }
        action = "";
    }

    // ================================================================
    // STEP 8 - UPDATE APPOINTMENT (POST)
    // ================================================================
    String updateMessage = "";
    boolean updateSuccess = false;

    if ("update".equals(action) && isPost) {
        request.setCharacterEncoding("UTF-8");
        String origDeptName   = param(request, "orig_department_name");
        String origDoctorName = param(request, "orig_doctor_name");
        String origApptDate   = param(request, "orig_appointment_date");
        String origApptTime   = param(request, "orig_appointment_time");
        String origReason     = param(request, "orig_reason_for_visit");

        String newDeptName   = param(request, "department_name");
        String newDoctorName = param(request, "doctor_name");
        String newApptDate   = param(request, "appointment_date");
        String newApptTime   = param(request, "appointment_time");
        String newReason     = param(request, "reason_for_visit");

        if (newDeptName.isEmpty() || newDoctorName.isEmpty() || newApptDate.isEmpty()
                || newApptTime.isEmpty() || newReason.isEmpty()) {
            updateMessage = "❌ All fields are required for the update.";
        } else {
            try {
                SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
                Date selectedDate = sdf.parse(newApptDate);
                if (selectedDate.before(sdf.parse(sdf.format(new Date())))) {
                    updateMessage = "❌ Appointment date cannot be in the past.";
                }
            } catch (Exception e) {
                updateMessage = "❌ Invalid appointment date format.";
            }
        }

        if (updateMessage.isEmpty()) {
            Connection conn = null;
            PreparedStatement checkPs = null;
            ResultSet checkRs = null;
            try {
                conn = getConnection();
                checkPs = conn.prepareStatement(
                    "SELECT doctor_name FROM doctors WHERE doctor_name = ? AND department_name = ?");
                checkPs.setString(1, newDoctorName);
                checkPs.setString(2, newDeptName);
                checkRs = checkPs.executeQuery();
                if (!checkRs.next()) {
                    updateMessage = "❌ The selected doctor does not belong to the selected department.";
                }
            } catch (SQLException e) {
                updateMessage = "❌ Database error during validation. Please try again.";
            } finally {
                closeQuietly(checkRs);
                closeQuietly(checkPs);
                closeQuietly(conn);
            }
        }

        if (updateMessage.isEmpty()) {
            // Identify the row by all original values + patient_phone; LIMIT 1 touches one row only.
            Connection conn = null;
            PreparedStatement ps = null;
            try {
                conn = getConnection();
                ps = conn.prepareStatement(
                    "UPDATE appointments SET department_name = ?, doctor_name = ?, appointment_date = ?, "
                    + "appointment_time = ?, reason_for_visit = ? "
                    + "WHERE patient_phone = ? AND department_name = ? AND doctor_name = ? "
                    + "AND appointment_date = ? AND appointment_time = ? AND reason_for_visit = ? LIMIT 1");
                ps.setString(1, newDeptName);
                ps.setString(2, newDoctorName);
                ps.setString(3, newApptDate);
                ps.setString(4, newApptTime);
                ps.setString(5, newReason);
                ps.setString(6, sessPhone);
                ps.setString(7, origDeptName);
                ps.setString(8, origDoctorName);
                ps.setString(9, origApptDate);
                ps.setString(10, origApptTime);
                ps.setString(11, origReason);

                int rows = ps.executeUpdate();
                if (rows > 0) {
                    updateSuccess = true;
                    updateMessage = "✅ Appointment updated successfully!";
                } else {
                    updateMessage = "❌ Could not find the appointment to update. It may have already been changed.";
                }
            } catch (SQLException e) {
                updateMessage = "❌ Failed to update appointment. Please try again.";
            } finally {
                closeQuietly(ps);
                closeQuietly(conn);
            }
        }
        action = "";
    }

    // ================================================================
    // STEP 9 - DELETE APPOINTMENT (POST)
    // ================================================================
    String deleteMessage = "";
    boolean deleteSuccess = false;

    if ("delete".equals(action) && isPost) {
        request.setCharacterEncoding("UTF-8");
        String delDeptName   = param(request, "department_name");
        String delDoctorName = param(request, "doctor_name");
        String delApptDate   = param(request, "appointment_date");
        String delApptTime   = param(request, "appointment_time");
        String delReason     = param(request, "reason_for_visit");

        if (delDeptName.isEmpty() || delDoctorName.isEmpty() || delApptDate.isEmpty()
                || delApptTime.isEmpty() || delReason.isEmpty()) {
            deleteMessage = "❌ Could not identify the appointment to delete.";
        } else {
            Connection conn = null;
            PreparedStatement ps = null;
            try {
                conn = getConnection();
                ps = conn.prepareStatement(
                    "DELETE FROM appointments WHERE patient_phone = ? AND department_name = ? "
                    + "AND doctor_name = ? AND appointment_date = ? AND appointment_time = ? "
                    + "AND reason_for_visit = ? LIMIT 1");
                ps.setString(1, sessPhone);
                ps.setString(2, delDeptName);
                ps.setString(3, delDoctorName);
                ps.setString(4, delApptDate);
                ps.setString(5, delApptTime);
                ps.setString(6, delReason);

                int rows = ps.executeUpdate();
                if (rows > 0) {
                    deleteSuccess = true;
                    deleteMessage = "✅ Appointment deleted successfully!";
                } else {
                    deleteMessage = "❌ Appointment not found. It may have already been deleted.";
                }
            } catch (SQLException e) {
                deleteMessage = "❌ Failed to delete appointment. Please try again.";
            } finally {
                closeQuietly(ps);
                closeQuietly(conn);
            }
        }
        action = "";
    }

    // ================================================================
    // STEP 10 - Load departments for the booking form
    // ================================================================
    List<String> departmentList = new ArrayList<String>();
    {
        Connection c = null;
        PreparedStatement p = null;
        ResultSet r = null;
        try {
            c = getConnection();
            p = c.prepareStatement("SELECT department_name FROM departments ORDER BY department_name");
            r = p.executeQuery();
            while (r.next()) {
                departmentList.add(r.getString("department_name"));
            }
        } catch (SQLException e) {
            // list stays empty
        } finally {
            closeQuietly(r);
            closeQuietly(p);
            closeQuietly(c);
        }
    }

    // ================================================================
    // STEP 11 - Load this patient's appointments
    // ================================================================
    List<Map<String, String>> appointmentList = new ArrayList<Map<String, String>>();
    {
        Connection c = null;
        PreparedStatement p = null;
        ResultSet r = null;
        try {
            c = getConnection();
            p = c.prepareStatement(
                "SELECT department_name, doctor_name, appointment_date, appointment_time, reason_for_visit, appointment_status "
                + "FROM appointments WHERE patient_phone = ? ORDER BY appointment_date DESC, appointment_time DESC");
            p.setString(1, sessPhone);
            r = p.executeQuery();
            while (r.next()) {
                Map<String, String> row = new LinkedHashMap<String, String>();
                row.put("department_name", r.getString("department_name"));
                row.put("doctor_name", r.getString("doctor_name"));
                row.put("appointment_date", r.getString("appointment_date"));
                row.put("appointment_time", r.getString("appointment_time"));
                row.put("reason_for_visit", r.getString("reason_for_visit"));
                row.put("appointment_status", r.getString("appointment_status"));
                appointmentList.add(row);
            }
        } catch (SQLException e) {
            // list stays empty
        } finally {
            closeQuietly(r);
            closeQuietly(p);
            closeQuietly(c);
        }
    }
%>
<!DOCTYPE html>
                                                                        <html lang="en">

                                                                        <head>
                                                                            <meta charset="UTF-8">
                                                                            <meta name="viewport"
                                                                                content="width=device-width, initial-scale=1.0">
                                                                            <meta name="description"
                                                                                content="Patient Dashboard – Manage your hospital appointments.">
                                                                            <title>Dashboard – Patient Management System
                                                                            </title>
                                                                            <link rel="stylesheet"
                                                                                href="patient_management_system.css">
                                                                            <style>
                                                                                /* Extra inline styles only needed on the dashboard page */
                                                                                .appt-actions {
                                                                                    display: flex;
                                                                                    gap: 8px;
                                                                                    flex-wrap: wrap;
                                                                                }

                                                                                body {
                                                                                    background: #f5f7fa;
                                                                                }
                                                                            </style>
                                                                        </head>

                                                                        <body>

                                                                            <!-- ============================================================
     NAVBAR
     ============================================================ -->
                                                                            <nav class="navbar">
                                                                                <div class="brand">
                                                                                    <span class="icon">🏥</span>
                                                                                    <span class="brand-text">Patient
                                                                                        Management System</span>
                                                                                </div>
                                                                                <div class="nav-links">
                                                                                    <!-- Logout button submits to this same JSP with action=logout -->
                                                                                    <form
                                                                                        action="patient_management_system.jsp"
                                                                                        method="get" style="margin:0;">
                                                                                        <input type="hidden"
                                                                                            name="action"
                                                                                            value="logout">
                                                                                        <button type="submit"
                                                                                            class="btn btn-logout">🔓
                                                                                            Logout</button>
                                                                                    </form>
                                                                                </div>
                                                                            </nav>

                                                                            <!-- ============================================================
     DASHBOARD MAIN CONTENT
     ============================================================ -->
                                                                            <div class="page-wrapper wide">

                                                                                <!-- Welcome Banner -->
                                                                                <div class="dashboard-header">
                                                                                    <div class="welcome-text">
                                                                                        <h2>👋 Welcome, <%=
                                                                                                esc(sessFirstName) %>!
                                                                                        </h2>
                                                                                        <p>Here is your patient
                                                                                            dashboard. Manage your
                                                                                            profile and appointments
                                                                                            below.</p>
                                                                                    </div>
                                                                                </div>

                                                                                <!-- ========================================================
         Messages (book / update / delete results)
         ======================================================== -->
                                                                                <% String pageMessage="" ; boolean
                                                                                    pageSuccess=false; if
                                                                                    (!bookMessage.isEmpty()) {
                                                                                    pageMessage=bookMessage;
                                                                                    pageSuccess=bookSuccess; } if
                                                                                    (!updateMessage.isEmpty()) {
                                                                                    pageMessage=updateMessage;
                                                                                    pageSuccess=updateSuccess; } if
                                                                                    (!deleteMessage.isEmpty()) {
                                                                                    pageMessage=deleteMessage;
                                                                                    pageSuccess=deleteSuccess; } %>
                                                                                    <% if (!pageMessage.isEmpty()) { %>
                                                                                        <div class="alert <%= pageSuccess ? "alert-success" : "alert-error" %>">
                                                                                            <%= esc(pageMessage) %>
                                                                                        </div>
                                                                                        <% } %>

                                                                                            <!-- ========================================================
         TWO-COLUMN DASHBOARD GRID
         Left: Patient Profile Card
         Right: Book Appointment + Appointments Table
         ======================================================== -->
                                                                                            <div class="dashboard-grid">

                                                                                                <!-- === LEFT: Patient Profile Card === -->
                                                                                                <div>
                                                                                                    <div
                                                                                                        class="profile-card">
                                                                                                        <div
                                                                                                            class="profile-avatar">
                                                                                                            👤</div>
                                                                                                        <div
                                                                                                            class="profile-name">
                                                                                                            <%= esc(sessFirstName
                                                                                                                + " " +
                                                                                                                sessLastName)
                                                                                                                %>
                                                                                                        </div>
                                                                                                        <div
                                                                                                            class="profile-phone">
                                                                                                            📞 <%=
                                                                                                                esc(sessPhone)
                                                                                                                %>
                                                                                                        </div>
                                                                                                        <ul
                                                                                                            class="profile-info-list">
                                                                                                            <li>
                                                                                                                <span
                                                                                                                    class="label">Email</span>
                                                                                                                <span
                                                                                                                    class="value">
                                                                                                                    <%= esc(sessEmail)
                                                                                                                        %>
                                                                                                                </span>
                                                                                                            </li>
                                                                                                            <li>
                                                                                                                <span
                                                                                                                    class="label">Date
                                                                                                                    of
                                                                                                                    Birth</span>
                                                                                                                <span
                                                                                                                    class="value">
                                                                                                                    <%= esc(sessDob)
                                                                                                                        %>
                                                                                                                </span>
                                                                                                            </li>
                                                                                                            <li>
                                                                                                                <span
                                                                                                                    class="label">Gender</span>
                                                                                                                <span
                                                                                                                    class="value">
                                                                                                                    <%= esc(sessGender)
                                                                                                                        %>
                                                                                                                </span>
                                                                                                            </li>
                                                                                                            <li>
                                                                                                                <span
                                                                                                                    class="label">Blood
                                                                                                                    Group</span>
                                                                                                                <span
                                                                                                                    class="value">
                                                                                                                    <%= esc(sessBloodGroup)
                                                                                                                        %>
                                                                                                                </span>
                                                                                                            </li>
                                                                                                            <li>
                                                                                                                <span
                                                                                                                    class="label">Address</span>
                                                                                                                <span
                                                                                                                    class="value">
                                                                                                                    <%= esc(sessAddress)
                                                                                                                        %>
                                                                                                                </span>
                                                                                                            </li>
                                                                                                        </ul>
                                                                                                    </div>
                                                                                                </div>
                                                                                                <!-- /profile column -->

                                                                                                <!-- === RIGHT: Main Content === -->
                                                                                                <div
                                                                                                    class="main-content">

                                                                                                    <!-- ================================================
                 BOOK APPOINTMENT FORM
                 ================================================ -->
                                                                                                    <div class="card">
                                                                                                        <div
                                                                                                            class="card-title">
                                                                                                            📅 Book an
                                                                                                            Appointment
                                                                                                        </div>

                                                                                                        <form
                                                                                                            action="patient_management_system.jsp"
                                                                                                            method="post"
                                                                                                            id="bookingForm"
                                                                                                            onsubmit="return validateBooking()">
                                                                                                            <input
                                                                                                                type="hidden"
                                                                                                                name="action"
                                                                                                                value="book">

                                                                                                            <!-- Department Dropdown (loaded from DB) -->
                                                                                                            <div
                                                                                                                class="form-group">
                                                                                                                <label
                                                                                                                    for="bookDept">Department
                                                                                                                    <span
                                                                                                                        class="required">*</span></label>
                                                                                                                <select
                                                                                                                    id="bookDept"
                                                                                                                    name="department_name"
                                                                                                                    class="form-control"
                                                                                                                    required
                                                                                                                    onchange="loadDoctors(this.value)">
                                                                                                                    <option
                                                                                                                        value="">
                                                                                                                        --
                                                                                                                        Select
                                                                                                                        Department
                                                                                                                        --
                                                                                                                    </option>
                                                                                                                    <% for
                                                                                                                        (String
                                                                                                                        dept
                                                                                                                        :
                                                                                                                        departmentList)
                                                                                                                        {
                                                                                                                        %>
                                                                                                                        <option
                                                                                                                            value="<%= esc(dept) %>">
                                                                                                                            <%= esc(dept)
                                                                                                                                %>
                                                                                                                        </option>
                                                                                                                        <% }
                                                                                                                            %>
                                                                                                                </select>
                                                                                                            </div>

                                                                                                            <!-- Doctor Dropdown (populated by JS Fetch when dept is selected) -->
                                                                                                            <div
                                                                                                                class="form-group">
                                                                                                                <label
                                                                                                                    for="bookDoctor">Doctor
                                                                                                                    <span
                                                                                                                        class="required">*</span></label>
                                                                                                                <select
                                                                                                                    id="bookDoctor"
                                                                                                                    name="doctor_name"
                                                                                                                    class="form-control"
                                                                                                                    required
                                                                                                                    disabled>
                                                                                                                    <option
                                                                                                                        value="">
                                                                                                                        --
                                                                                                                        Select
                                                                                                                        Department
                                                                                                                        First
                                                                                                                        --
                                                                                                                    </option>
                                                                                                                </select>
                                                                                                                <p class="helper-text"
                                                                                                                    id="doctorHelperText">
                                                                                                                    Select
                                                                                                                    a
                                                                                                                    department
                                                                                                                    to
                                                                                                                    see
                                                                                                                    available
                                                                                                                    doctors.
                                                                                                                </p>
                                                                                                            </div>

                                                                                                            <div
                                                                                                                class="form-row">
                                                                                                                <div
                                                                                                                    class="form-group">
                                                                                                                    <label
                                                                                                                        for="bookDate">Appointment
                                                                                                                        Date
                                                                                                                        <span
                                                                                                                            class="required">*</span></label>
                                                                                                                    <input
                                                                                                                        type="date"
                                                                                                                        id="bookDate"
                                                                                                                        name="appointment_date"
                                                                                                                        class="form-control"
                                                                                                                        required>
                                                                                                                </div>
                                                                                                                <div
                                                                                                                    class="form-group">
                                                                                                                    <label
                                                                                                                        for="bookTime">Appointment
                                                                                                                        Time
                                                                                                                        <span
                                                                                                                            class="required">*</span></label>
                                                                                                                    <input
                                                                                                                        type="time"
                                                                                                                        id="bookTime"
                                                                                                                        name="appointment_time"
                                                                                                                        class="form-control"
                                                                                                                        required>
                                                                                                                </div>
                                                                                                            </div>

                                                                                                            <div
                                                                                                                class="form-group">
                                                                                                                <label
                                                                                                                    for="bookReason">Reason
                                                                                                                    for
                                                                                                                    Visit
                                                                                                                    <span
                                                                                                                        class="required">*</span></label>
                                                                                                                <input
                                                                                                                    type="text"
                                                                                                                    id="bookReason"
                                                                                                                    name="reason_for_visit"
                                                                                                                    class="form-control"
                                                                                                                    placeholder="Briefly describe your reason"
                                                                                                                    maxlength="255"
                                                                                                                    required>
                                                                                                            </div>

                                                                                                            <button
                                                                                                                type="submit"
                                                                                                                class="btn btn-primary">📋
                                                                                                                Book
                                                                                                                Appointment</button>
                                                                                                        </form>
                                                                                                    </div>
                                                                                                    <!-- /book card -->

                                                                                                    <!-- ================================================
                 APPOINTMENTS TABLE
                 ================================================ -->
                                                                                                    <div class="card">
                                                                                                        <div
                                                                                                            class="section-header">
                                                                                                            <div
                                                                                                                class="section-title">
                                                                                                                🗓️ My
                                                                                                                Appointments
                                                                                                            </div>
                                                                                                        </div>

                                                                                                        <% if
                                                                                                            (appointmentList.isEmpty())
                                                                                                            { %>
                                                                                                            <div
                                                                                                                class="no-data">
                                                                                                                <div
                                                                                                                    class="no-data-icon">
                                                                                                                    📭
                                                                                                                </div>
                                                                                                                <p>You
                                                                                                                    have
                                                                                                                    no
                                                                                                                    appointments
                                                                                                                    yet.
                                                                                                                    Book
                                                                                                                    one
                                                                                                                    above!
                                                                                                                </p>
                                                                                                            </div>
                                                                                                            <% } else {
                                                                                                                %>
                                                                                                                <div
                                                                                                                    class="table-wrapper">
                                                                                                                    <table>
                                                                                                                        <thead>
                                                                                                                            <tr>
                                                                                                                                <th>#
                                                                                                                                </th>
                                                                                                                                <th>Department
                                                                                                                                </th>
                                                                                                                                <th>Doctor
                                                                                                                                </th>
                                                                                                                                <th>Date
                                                                                                                                </th>
                                                                                                                                <th>Time
                                                                                                                                </th>
                                                                                                                                <th>Reason
                                                                                                                                </th>
                                                                                                                                <th>Status
                                                                                                                                </th>
                                                                                                                                <th>Actions
                                                                                                                                </th>
                                                                                                                            </tr>
                                                                                                                        </thead>
                                                                                                                        <tbody>
                                                                                                                            <%
    int apptIndex = 0;
    for (Map<String, String> appt : appointmentList) {
        apptIndex++;
        String aDept = appt.get("department_name");
        String aDoctor = appt.get("doctor_name");
        String aDate = appt.get("appointment_date");
        String aTime = appt.get("appointment_time");
        String aReason = appt.get("reason_for_visit");
        String aStatus = appt.get("appointment_status");
        String displayTime = (aTime != null && aTime.length() >= 5) ? aTime.substring(0, 5) : aTime;
%>
                                                                                                                                <tr>
                                                                                                                                    <td>
                                                                                                                                        <%= apptIndex
                                                                                                                                            %>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <%= esc(aDept)
                                                                                                                                            %>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <%= esc(aDoctor)
                                                                                                                                            %>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <%= esc(aDate)
                                                                                                                                            %>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <%= esc(displayTime)
                                                                                                                                            %>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <%= esc(aReason)
                                                                                                                                            %>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <span
                                                                                                                                            class="status-badge <%= "Booked".equals(aStatus) ? "" : "cancelled" %>">
                                                                                                                                            <%= esc(aStatus)
                                                                                                                                                %>
                                                                                                                                        </span>
                                                                                                                                    </td>
                                                                                                                                    <td>
                                                                                                                                        <div
                                                                                                                                            class="appt-actions">
                                                                                                                                            <!-- Edit: pass values via data-* attributes (safe, no inline JS quoting issues) -->
                                                                                                                                            <button
                                                                                                                                                class="btn btn-edit btn-sm appt-edit-btn"
                                                                                                                                                data-dept="<%= esc(aDept) %>"
                                                                                                                                                data-doctor="<%= esc(aDoctor) %>"
                                                                                                                                                data-date="<%= esc(aDate) %>"
                                                                                                                                                data-time="<%= esc(aTime) %>"
                                                                                                                                                data-reason="<%= esc(aReason) %>">✏️
                                                                                                                                                Edit</button>

                                                                                                                                            <!-- Delete: pass values via data-* attributes -->
                                                                                                                                            <button
                                                                                                                                                class="btn btn-delete btn-sm appt-delete-btn"
                                                                                                                                                data-dept="<%= esc(aDept) %>"
                                                                                                                                                data-doctor="<%= esc(aDoctor) %>"
                                                                                                                                                data-date="<%= esc(aDate) %>"
                                                                                                                                                data-time="<%= esc(aTime) %>"
                                                                                                                                                data-reason="<%= esc(aReason) %>">🗑️
                                                                                                                                                Delete</button>
                                                                                                                                        </div>
                                                                                                                                    </td>
                                                                                                                                </tr>
                                                                                                                                <% }
                                                                                                                                    %>
                                                                                                                        </tbody>
                                                                                                                    </table>
                                                                                                                </div>
                                                                                                                <% } %>

                                                                                                                    <!-- Limitation notice -->
                                                                                                                    <div class="alert alert-info"
                                                                                                                        style="margin-top:16px; font-size:0.82rem;">
                                                                                                                        ⚠️
                                                                                                                        <strong>College
                                                                                                                            Demo
                                                                                                                            Limitation:</strong>
                                                                                                                        The
                                                                                                                        appointments
                                                                                                                        table
                                                                                                                        has
                                                                                                                        no
                                                                                                                        unique
                                                                                                                        ID
                                                                                                                        column.
                                                                                                                        Edit
                                                                                                                        and
                                                                                                                        Delete
                                                                                                                        identify
                                                                                                                        records
                                                                                                                        by
                                                                                                                        matching
                                                                                                                        all
                                                                                                                        field
                                                                                                                        values.
                                                                                                                        If
                                                                                                                        two
                                                                                                                        appointments
                                                                                                                        are
                                                                                                                        identical,
                                                                                                                        only
                                                                                                                        one
                                                                                                                        is
                                                                                                                        affected.
                                                                                                                        This
                                                                                                                        is
                                                                                                                        documented
                                                                                                                        and
                                                                                                                        expected
                                                                                                                        for
                                                                                                                        this
                                                                                                                        demo
                                                                                                                        schema.
                                                                                                                    </div>

                                                                                                    </div>
                                                                                                    <!-- /appointments card -->

                                                                                                </div>
                                                                                                <!-- /main-content -->
                                                                                            </div>
                                                                                            <!-- /dashboard-grid -->
                                                                            </div><!-- /page-wrapper -->


                                                                            <!-- ============================================================
     EDIT APPOINTMENT MODAL
     ============================================================ -->
                                                                            <div class="modal-overlay" id="editModal">
                                                                                <div class="modal-box">
                                                                                    <button class="modal-close"
                                                                                        onclick="closeEditModal()"
                                                                                        title="Close">✕</button>
                                                                                    <div class="modal-title">✏️ Update
                                                                                        Appointment</div>

                                                                                    <form
                                                                                        action="patient_management_system.jsp"
                                                                                        method="post" id="editForm"
                                                                                        onsubmit="return validateEdit()">
                                                                                        <input type="hidden"
                                                                                            name="action"
                                                                                            value="update">

                                                                                        <!-- Hidden fields store the ORIGINAL values so the JSP can find the record -->
                                                                                        <input type="hidden"
                                                                                            id="origDept"
                                                                                            name="orig_department_name">
                                                                                        <input type="hidden"
                                                                                            id="origDoctor"
                                                                                            name="orig_doctor_name">
                                                                                        <input type="hidden"
                                                                                            id="origDate"
                                                                                            name="orig_appointment_date">
                                                                                        <input type="hidden"
                                                                                            id="origTime"
                                                                                            name="orig_appointment_time">
                                                                                        <input type="hidden"
                                                                                            id="origReason"
                                                                                            name="orig_reason_for_visit">

                                                                                        <!-- New values the patient can edit -->
                                                                                        <div class="form-group">
                                                                                            <label
                                                                                                for="editDept">Department
                                                                                                <span
                                                                                                    class="required">*</span></label>
                                                                                            <select id="editDept"
                                                                                                name="department_name"
                                                                                                class="form-control"
                                                                                                required
                                                                                                onchange="loadDoctorsEdit(this.value)">
                                                                                                <option value="">--
                                                                                                    Select Department --
                                                                                                </option>
                                                                                                <% for (String dept :
                                                                                                    departmentList) { %>
                                                                                                    <option
                                                                                                        value="<%= esc(dept) %>">
                                                                                                        <%= esc(dept) %>
                                                                                                    </option>
                                                                                                    <% } %>
                                                                                            </select>
                                                                                        </div>

                                                                                        <div class="form-group">
                                                                                            <label
                                                                                                for="editDoctor">Doctor
                                                                                                <span
                                                                                                    class="required">*</span></label>
                                                                                            <select id="editDoctor"
                                                                                                name="doctor_name"
                                                                                                class="form-control"
                                                                                                required disabled>
                                                                                                <option value="">--
                                                                                                    Select Department
                                                                                                    First --</option>
                                                                                            </select>
                                                                                        </div>

                                                                                        <div class="form-row">
                                                                                            <div class="form-group">
                                                                                                <label
                                                                                                    for="editDate">Appointment
                                                                                                    Date <span
                                                                                                        class="required">*</span></label>
                                                                                                <input type="date"
                                                                                                    id="editDate"
                                                                                                    name="appointment_date"
                                                                                                    class="form-control"
                                                                                                    required>
                                                                                            </div>
                                                                                            <div class="form-group">
                                                                                                <label
                                                                                                    for="editTime">Appointment
                                                                                                    Time <span
                                                                                                        class="required">*</span></label>
                                                                                                <input type="time"
                                                                                                    id="editTime"
                                                                                                    name="appointment_time"
                                                                                                    class="form-control"
                                                                                                    required>
                                                                                            </div>
                                                                                        </div>

                                                                                        <div class="form-group">
                                                                                            <label
                                                                                                for="editReason">Reason
                                                                                                for Visit <span
                                                                                                    class="required">*</span></label>
                                                                                            <input type="text"
                                                                                                id="editReason"
                                                                                                name="reason_for_visit"
                                                                                                class="form-control"
                                                                                                placeholder="Reason for visit"
                                                                                                maxlength="255"
                                                                                                required>
                                                                                        </div>

                                                                                        <div
                                                                                            style="display:flex; gap:12px; margin-top:8px;">
                                                                                            <button type="submit"
                                                                                                class="btn btn-primary"
                                                                                                style="flex:1;">💾 Save
                                                                                                Changes</button>
                                                                                            <button type="button"
                                                                                                class="btn btn-edit"
                                                                                                style="flex:0 0 auto;"
                                                                                                onclick="closeEditModal()">Cancel</button>
                                                                                        </div>
                                                                                    </form>
                                                                                </div>
                                                                            </div>


                                                                            <!-- ============================================================
     HIDDEN DELETE FORM
     Submitted programmatically by confirmDelete()
     ============================================================ -->
                                                                            <form action="patient_management_system.jsp"
                                                                                method="post" id="deleteForm"
                                                                                style="display:none;">
                                                                                <input type="hidden" name="action"
                                                                                    value="delete">
                                                                                <input type="hidden" id="delDept"
                                                                                    name="department_name">
                                                                                <input type="hidden" id="delDoctor"
                                                                                    name="doctor_name">
                                                                                <input type="hidden" id="delDate"
                                                                                    name="appointment_date">
                                                                                <input type="hidden" id="delTime"
                                                                                    name="appointment_time">
                                                                                <input type="hidden" id="delReason"
                                                                                    name="reason_for_visit">
                                                                            </form>


                                                                            <!-- ============================================================
     JAVASCRIPT
     ============================================================ -->
                                                                            <script>
                                                                                // ---------------------------------------------------------------
                                                                                // Set the minimum allowed appointment date to today
                                                                                // ---------------------------------------------------------------
                                                                                (function setMinDates() {
                                                                                    var today = new Date().toISOString().split('T')[0]; // "YYYY-MM-DD"
                                                                                    var bookDateInput = document.getElementById('bookDate');
                                                                                    var editDateInput = document.getElementById('editDate');
                                                                                    if (bookDateInput) bookDateInput.min = today;
                                                                                    if (editDateInput) editDateInput.min = today;
                                                                                })();

                                                                                // ---------------------------------------------------------------
                                                                                // Event delegation for Edit and Delete buttons.
                                                                                // We read values from data-* attributes — 100% safe, no quoting
                                                                                // or string escaping issues.
                                                                                // ---------------------------------------------------------------
                                                                                document.addEventListener('click', function (e) {

                                                                                    // ---- EDIT button clicked ----
                                                                                    var editBtn = e.target.closest('.appt-edit-btn');
                                                                                    if (editBtn) {
                                                                                        var dept = editBtn.getAttribute('data-dept');
                                                                                        var doctor = editBtn.getAttribute('data-doctor');
                                                                                        var date = editBtn.getAttribute('data-date');
                                                                                        var time = editBtn.getAttribute('data-time');
                                                                                        var reason = editBtn.getAttribute('data-reason');
                                                                                        openEditModal(dept, doctor, date, time, reason);
                                                                                        return;
                                                                                    }

                                                                                    // ---- DELETE button clicked ----
                                                                                    var delBtn = e.target.closest('.appt-delete-btn');
                                                                                    if (delBtn) {
                                                                                        var dept = delBtn.getAttribute('data-dept');
                                                                                        var doctor = delBtn.getAttribute('data-doctor');
                                                                                        var date = delBtn.getAttribute('data-date');
                                                                                        var time = delBtn.getAttribute('data-time');
                                                                                        var reason = delBtn.getAttribute('data-reason');
                                                                                        confirmDelete(dept, doctor, date, time, reason);
                                                                                        return;
                                                                                    }
                                                                                });

                                                                                // ---------------------------------------------------------------
                                                                                // Fetch doctors from the JSP using the Fetch API
                                                                                // action=doctors&department=<name>  returns a JSON array like:
                                                                                // [{"name":"Dr. X", "spec":"Cardiologist"}, ...]
                                                                                // ---------------------------------------------------------------
                                                                                function loadDoctors(deptName) {
                                                                                    var doctorSelect = document.getElementById('bookDoctor');
                                                                                    var helperText = document.getElementById('doctorHelperText');

                                                                                    // Disable and reset while loading
                                                                                    doctorSelect.disabled = true;
                                                                                    doctorSelect.innerHTML = '<option value="">Loading doctors...</option>';

                                                                                    if (!deptName) {
                                                                                        doctorSelect.innerHTML = '<option value="">-- Select Department First --</option>';
                                                                                        helperText.textContent = 'Select a department to see available doctors.';
                                                                                        return;
                                                                                    }

                                                                                    // Fetch the doctor list as JSON from the JSP
                                                                                    fetch('patient_management_system.jsp?action=doctors&department=' + encodeURIComponent(deptName))
                                                                                        .then(function (response) {
                                                                                            // Check that the response was OK
                                                                                            if (!response.ok) {
                                                                                                throw new Error('Network response was not ok');
                                                                                            }
                                                                                            return response.json();
                                                                                        })
                                                                                        .then(function (doctors) {
                                                                                            doctorSelect.innerHTML = '<option value="">-- Select Doctor --</option>';

                                                                                            if (doctors.length === 0) {
                                                                                                doctorSelect.innerHTML = '<option value="">No doctors found for this department</option>';
                                                                                                helperText.textContent = 'No doctors are listed for this department.';
                                                                                                return;
                                                                                            }

                                                                                            doctors.forEach(function (doc) {
                                                                                                var option = document.createElement('option');
                                                                                                option.value = doc.name;
                                                                                                option.textContent = doc.name + ' (' + doc.spec + ')';
                                                                                                doctorSelect.appendChild(option);
                                                                                            });

                                                                                            doctorSelect.disabled = false;
                                                                                            helperText.textContent = doctors.length + ' doctor(s) available.';
                                                                                        })
                                                                                        .catch(function (err) {
                                                                                            doctorSelect.innerHTML = '<option value="">Error loading doctors. Please try again.</option>';
                                                                                            helperText.textContent = 'Could not load doctors. Check the console for details.';
                                                                                            console.error('Doctor fetch error:', err);
                                                                                        });
                                                                                }

                                                                                // Same function but for the Edit modal
                                                                                function loadDoctorsEdit(deptName) {
                                                                                    var doctorSelect = document.getElementById('editDoctor');

                                                                                    doctorSelect.disabled = true;
                                                                                    doctorSelect.innerHTML = '<option value="">Loading doctors...</option>';

                                                                                    if (!deptName) {
                                                                                        doctorSelect.innerHTML = '<option value="">-- Select Department First --</option>';
                                                                                        return;
                                                                                    }

                                                                                    // Store the current doctor value to re-select it after loading
                                                                                    var currentDoctor = doctorSelect.dataset.preselect || '';

                                                                                    fetch('patient_management_system.jsp?action=doctors&department=' + encodeURIComponent(deptName))
                                                                                        .then(function (response) { return response.json(); })
                                                                                        .then(function (doctors) {
                                                                                            doctorSelect.innerHTML = '<option value="">-- Select Doctor --</option>';

                                                                                            doctors.forEach(function (doc) {
                                                                                                var option = document.createElement('option');
                                                                                                option.value = doc.name;
                                                                                                option.textContent = doc.name + ' (' + doc.spec + ')';
                                                                                                if (doc.name === currentDoctor) {
                                                                                                    option.selected = true; // re-select original doctor
                                                                                                }
                                                                                                doctorSelect.appendChild(option);
                                                                                            });

                                                                                            doctorSelect.disabled = false;
                                                                                        })
                                                                                        .catch(function (err) {
                                                                                            doctorSelect.innerHTML = '<option value="">Error loading doctors.</option>';
                                                                                            console.error('Doctor fetch error:', err);
                                                                                        });
                                                                                }

                                                                                // ---------------------------------------------------------------
                                                                                // Validate booking form before submit
                                                                                // ---------------------------------------------------------------
                                                                                function validateBooking() {
                                                                                    var dept = document.getElementById('bookDept').value;
                                                                                    var doctor = document.getElementById('bookDoctor').value;
                                                                                    var date = document.getElementById('bookDate').value;
                                                                                    var time = document.getElementById('bookTime').value;
                                                                                    var reason = document.getElementById('bookReason').value.trim();
                                                                                    var today = new Date().toISOString().split('T')[0];

                                                                                    if (!dept) {
                                                                                        alert('Please select a department.');
                                                                                        return false;
                                                                                    }
                                                                                    if (!doctor) {
                                                                                        alert('Please select a doctor.');
                                                                                        return false;
                                                                                    }
                                                                                    if (!date) {
                                                                                        alert('Please select an appointment date.');
                                                                                        return false;
                                                                                    }
                                                                                    if (date < today) {
                                                                                        alert('Appointment date cannot be in the past.');
                                                                                        return false;
                                                                                    }
                                                                                    if (!time) {
                                                                                        alert('Please select an appointment time.');
                                                                                        return false;
                                                                                    }
                                                                                    if (!reason) {
                                                                                        alert('Please enter the reason for your visit.');
                                                                                        return false;
                                                                                    }
                                                                                    return true;
                                                                                }

                                                                                // ---------------------------------------------------------------
                                                                                // Open the Edit modal and pre-fill form fields
                                                                                // ---------------------------------------------------------------
                                                                                function openEditModal(dept, doctor, date, time, reason) {
                                                                                    // Store original values in hidden fields
                                                                                    document.getElementById('origDept').value = dept;
                                                                                    document.getElementById('origDoctor').value = doctor;
                                                                                    document.getElementById('origDate').value = date;
                                                                                    document.getElementById('origTime').value = time;
                                                                                    document.getElementById('origReason').value = reason;

                                                                                    // Pre-fill visible form fields
                                                                                    document.getElementById('editDate').value = date;
                                                                                    document.getElementById('editTime').value = time;
                                                                                    document.getElementById('editReason').value = reason;

                                                                                    // Select department in the dropdown
                                                                                    var editDeptSelect = document.getElementById('editDept');
                                                                                    editDeptSelect.value = dept;

                                                                                    // Store the doctor to pre-select after loading
                                                                                    document.getElementById('editDoctor').dataset.preselect = doctor;

                                                                                    // Load doctors for this department and pre-select the current doctor
                                                                                    loadDoctorsEdit(dept);

                                                                                    // Show the modal
                                                                                    document.getElementById('editModal').classList.add('active');
                                                                                }

                                                                                // ---------------------------------------------------------------
                                                                                // Close the Edit modal
                                                                                // ---------------------------------------------------------------
                                                                                function closeEditModal() {
                                                                                    document.getElementById('editModal').classList.remove('active');
                                                                                }

                                                                                // Close modal if user clicks outside the modal box
                                                                                document.getElementById('editModal').addEventListener('click', function (e) {
                                                                                    if (e.target === this) {
                                                                                        closeEditModal();
                                                                                    }
                                                                                });

                                                                                // ---------------------------------------------------------------
                                                                                // Validate edit form before submit
                                                                                // ---------------------------------------------------------------
                                                                                function validateEdit() {
                                                                                    var dept = document.getElementById('editDept').value;
                                                                                    var doctor = document.getElementById('editDoctor').value;
                                                                                    var date = document.getElementById('editDate').value;
                                                                                    var time = document.getElementById('editTime').value;
                                                                                    var reason = document.getElementById('editReason').value.trim();
                                                                                    var today = new Date().toISOString().split('T')[0];

                                                                                    if (!dept || !doctor || !date || !time || !reason) {
                                                                                        alert('Please fill in all fields.');
                                                                                        return false;
                                                                                    }
                                                                                    if (date < today) {
                                                                                        alert('Appointment date cannot be in the past.');
                                                                                        return false;
                                                                                    }
                                                                                    return true;
                                                                                }

                                                                                // ---------------------------------------------------------------
                                                                                // Confirm and submit the delete form
                                                                                // ---------------------------------------------------------------
                                                                                function confirmDelete(dept, doctor, date, time, reason) {
                                                                                    var confirmMsg = 'Are you sure you want to delete this appointment?\n\n'
                                                                                        + 'Department: ' + dept + '\n'
                                                                                        + 'Doctor: ' + doctor + '\n'
                                                                                        + 'Date: ' + date + '\n'
                                                                                        + 'Time: ' + time + '\n'
                                                                                        + 'Reason: ' + reason + '\n\n'
                                                                                        + 'This action cannot be undone.';

                                                                                    if (confirm(confirmMsg)) {
                                                                                        // Fill the hidden delete form and submit it via POST
                                                                                        document.getElementById('delDept').value = dept;
                                                                                        document.getElementById('delDoctor').value = doctor;
                                                                                        document.getElementById('delDate').value = date;
                                                                                        document.getElementById('delTime').value = time;
                                                                                        document.getElementById('delReason').value = reason;
                                                                                        document.getElementById('deleteForm').submit();
                                                                                    }
                                                                                }
                                                                            </script>

                                                                        </body>

                                                                        </html>
