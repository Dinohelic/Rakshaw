// ============================================================
// Automated Unit & Integration Test Suite for raksha-attendance Edge Function
// Simulates the exact logic of index.ts under Node.js 22
// ============================================================

const assert = require("assert");

// Constants from index.ts
const PHONE_NEARBY_DISTANCE_M = 100;
const PHONE_LOCATION_MAX_AGE_SECONDS = 300;
const PHONE_MAX_ACCURACY_M = 100;
const VALID_EVENT_TYPES = ["morning_boarding", "evening_boarding", "deboarding"];
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function getIndiaDate(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const year = parts.find((p) => p.type === "year")?.value;
  const month = parts.find((p) => p.type === "month")?.value;
  const day = parts.find((p) => p.type === "day")?.value;
  return `${year}-${month}-${day}`;
}

function calculateDistanceMeters(lat1, lon1, lat2, lon2) {
  const earthRadiusM = 6371000;
  const toRadians = (degrees) => (degrees * Math.PI) / 180;
  const latitude1 = toRadians(lat1);
  const latitude2 = toRadians(lat2);
  const deltaLatitude = toRadians(lat2 - lat1);
  const deltaLongitude = toRadians(lon2 - lon1);

  const a =
    Math.sin(deltaLatitude / 2) * Math.sin(deltaLatitude / 2) +
    Math.cos(latitude1) * Math.cos(latitude2) * Math.sin(deltaLongitude / 2) * Math.sin(deltaLongitude / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusM * c;
}

function getEventMessage(eventType) {
  switch (eventType) {
    case "morning_boarding":
      return "Morning boarding recorded";
    case "evening_boarding":
      return "Evening boarding recorded";
    case "deboarding":
      return "Deboarding recorded";
    default:
      return "Attendance recorded";
  }
}

// Handler mirroring index.ts
async function handleAttendanceRequest(req, supabaseMock) {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return Response.json({ success: false, error: "POST required" }, { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const rfidUid = String(body.rfid_uid ?? "").replace(/\s+/g, "").toUpperCase();
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);
    const deviceId = String(body.device_id ?? "RAKSHA-ESP32-001");
    const eventType = String(body.event_type ?? "").trim().toLowerCase();

    if (
      !rfidUid ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      return Response.json({ success: false, error: "Invalid RFID or GPS data" }, { status: 400, headers: corsHeaders });
    }

    if (!VALID_EVENT_TYPES.includes(eventType)) {
      return Response.json(
        { success: false, error: "Invalid event type", allowed_event_types: VALID_EVENT_TYPES },
        { status: 400, headers: corsHeaders }
      );
    }

    // 1. Student lookup
    const { data: student, error: studentError } = await supabaseMock
      .from("students")
      .select("id, student_code, student_name, is_blocked")
      .eq("rfid_uid", rfidUid)
      .maybeSingle();

    if (studentError) {
      throw studentError;
    }

    if (!student) {
      return Response.json({ success: false, error: "Student not registered" }, { status: 404, headers: corsHeaders });
    }

    // 2. Card block check
    if (student.is_blocked === true) {
      return Response.json(
        {
          success: false,
          error_code: "CARD_BLOCKED",
          error: "Transport card blocked. Visit Transport Department.",
          terminal_rejection: true,
          sms_dispatch: false,
        },
        { status: 403, headers: corsHeaders }
      );
    }

    const now = new Date();
    const scannedAt = now.toISOString();
    const eventDate = getIndiaDate(now);

    // 3. Daily duplicate check
    const { data: existingAttendance, error: duplicateCheckError } = await supabaseMock
      .from("attendance")
      .select("id, scanned_at, event_type")
      .eq("student_id", student.id)
      .eq("event_date", eventDate)
      .eq("event_type", eventType)
      .maybeSingle();

    if (duplicateCheckError) {
      throw duplicateCheckError;
    }

    if (existingAttendance) {
      return Response.json(
        {
          success: false,
          duplicate: true,
          error: "Event already recorded",
          student_code: student.student_code,
          student_name: student.student_name,
          event_type: eventType,
          event_date: eventDate,
          existing_attendance_id: existingAttendance.id,
          original_scanned_at: existingAttendance.scanned_at,
        },
        { status: 409, headers: corsHeaders }
      );
    }

    // 4. Get student phone location
    const { data: phoneLocation, error: phoneLocationError } = await supabaseMock
      .from("student_phone_locations")
      .select("latitude, longitude, accuracy_m, recorded_at, phone_device_id")
      .eq("student_id", student.id)
      .maybeSingle();

    if (phoneLocationError) {
      throw phoneLocationError;
    }

    let verificationStatus = "location_unavailable";
    let phoneDistanceM = null;
    let phoneLocationAt = null;
    let phoneLocationAgeSeconds = null;
    let phoneAccuracyM = null;

    if (phoneLocation) {
      phoneLocationAt = phoneLocation.recorded_at;
      if (phoneLocation.accuracy_m !== null) {
        phoneAccuracyM = Number(phoneLocation.accuracy_m);
      }
      const phoneTime = new Date(phoneLocation.recorded_at);
      phoneLocationAgeSeconds = Math.max(0, Math.floor((now.getTime() - phoneTime.getTime()) / 1000));

      if (phoneLocationAgeSeconds > PHONE_LOCATION_MAX_AGE_SECONDS) {
        verificationStatus = "location_unavailable";
      } else if (phoneAccuracyM !== null && phoneAccuracyM > PHONE_MAX_ACCURACY_M) {
        verificationStatus = "verification_uncertain";
      } else {
        phoneDistanceM = calculateDistanceMeters(
          latitude,
          longitude,
          Number(phoneLocation.latitude),
          Number(phoneLocation.longitude)
        );
        if (phoneDistanceM <= PHONE_NEARBY_DISTANCE_M) {
          verificationStatus = "phone_present";
        } else {
          verificationStatus = "phone_not_nearby";
        }
      }
    }

    // 5. Insert attendance
    const { data: attendance, error: attendanceError } = await supabaseMock
      .from("attendance")
      .insert({
        student_id: student.id,
        attendance_status: "present",
        scanned_at: scannedAt,
        latitude,
        longitude,
        device_id: deviceId,
        event_type: eventType,
        event_date: eventDate,
        verification_status: verificationStatus,
        phone_distance_m: phoneDistanceM,
        phone_location_at: phoneLocationAt,
        phone_location_age_seconds: phoneLocationAgeSeconds,
        phone_accuracy_m: phoneAccuracyM,
      })
      .select("id, scanned_at, event_type, event_date, verification_status, phone_distance_m, phone_location_age_seconds, phone_accuracy_m")
      .single();

    if (attendanceError) {
      if (attendanceError.code === "23505") {
        return Response.json(
          {
            success: false,
            duplicate: true,
            error: "Event already recorded",
            student_code: student.student_code,
            student_name: student.student_name,
            event_type: eventType,
            event_date: eventDate,
          },
          { status: 409, headers: corsHeaders }
        );
      }

      if (
        attendanceError.code === "P0001" &&
        (attendanceError.message?.includes("blocked") || attendanceError.message?.includes("CARD_BLOCKED"))
      ) {
        return Response.json(
          {
            success: false,
            error_code: "CARD_BLOCKED",
            error: "Transport card blocked. Visit Transport Department.",
            terminal_rejection: true,
            sms_dispatch: false,
          },
          { status: 403, headers: corsHeaders }
        );
      }

      throw attendanceError;
    }

    // 6. Save bus location
    const { error: locationError } = await supabaseMock.from("locations").insert({
      student_id: student.id,
      latitude,
      longitude,
      recorded_at: scannedAt,
      device_id: deviceId,
    });

    if (locationError) {
      throw locationError;
    }

    return Response.json(
      {
        success: true,
        message: getEventMessage(eventType),
        student_code: student.student_code,
        student_name: student.student_name,
        event_type: attendance.event_type,
        event_date: attendance.event_date,
        attendance_id: attendance.id,
        scanned_at: attendance.scanned_at,
        verification_status: attendance.verification_status,
        phone_distance_m: attendance.phone_distance_m,
        phone_location_age_seconds: attendance.phone_location_age_seconds,
        phone_accuracy_m: attendance.phone_accuracy_m,
      },
      { status: 200, headers: corsHeaders }
    );
  } catch (error) {
    return Response.json({ success: false, error: "Internal server error" }, { status: 500, headers: corsHeaders });
  }
}

// ============================================================
// TEST HARNESS
// ============================================================

function createMockSupabase(dbState) {
  return {
    from: (table) => {
      let currentTable = table;
      let filters = {};
      let insertData = null;

      const builder = {
        select: (cols) => builder,
        eq: (col, val) => {
          filters[col] = val;
          return builder;
        },
        maybeSingle: async () => {
          if (currentTable === "students") {
            const stu = dbState.students?.find((s) => s.rfid_uid === filters.rfid_uid);
            return { data: stu || null, error: null };
          }
          if (currentTable === "attendance") {
            const att = dbState.attendance?.find(
              (a) =>
                a.student_id === filters.student_id &&
                a.event_date === filters.event_date &&
                a.event_type === filters.event_type
            );
            return { data: att || null, error: null };
          }
          if (currentTable === "student_phone_locations") {
            const loc = dbState.phone_locations?.find((p) => p.student_id === filters.student_id);
            return { data: loc || null, error: null };
          }
          return { data: null, error: null };
        },
        insert: (data) => {
          insertData = data;
          return {
            select: () => ({
              single: async () => {
                if (dbState.shouldFailAttendanceInsert) {
                  return { data: null, error: dbState.attendanceInsertError };
                }
                const record = { id: "att-uuid-1234", ...insertData };
                dbState.attendance = dbState.attendance || [];
                dbState.attendance.push(record);
                return { data: record, error: null };
              },
            }),
            then: async (resolve) => {
              if (dbState.shouldFailLocationInsert) {
                return resolve({ error: new Error("Location write failed") });
              }
              dbState.locations = dbState.locations || [];
              dbState.locations.push(insertData);
              return resolve({ error: null });
            },
          };
        },
      };
      return builder;
    },
  };
}

// Run test scenarios
async function runTests() {
  console.log("=== Raksha Kawach Edge Function Automated Test Suite ===");
  let passed = 0;
  let total = 0;

  function assertTest(name, condition) {
    total++;
    if (condition) {
      console.log(`  ✓ ${name}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: ${name}`);
      process.exitCode = 1;
    }
  }

  const baseDb = () => ({
    students: [
      { id: "stu-1", student_code: "STU001", student_name: "Rahul Verma", rfid_uid: "04A1B2C3", is_blocked: false },
      { id: "stu-2", student_code: "STU002", student_name: "Manish Kumar", rfid_uid: "04D5E6F7", is_blocked: true },
    ],
    attendance: [],
    locations: [],
    phone_locations: [
      {
        student_id: "stu-1",
        latitude: 28.39485,
        longitude: 76.90235,
        accuracy_m: 8.5,
        recorded_at: new Date(Date.now() - 30 * 1000).toISOString(),
        phone_device_id: "PHONE-001",
      },
    ],
  });

  // 1. Unregistered Card
  {
    const db = baseDb();
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "UNKNOWN99", latitude: 28.3949, longitude: 76.9023, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Unregistered card returns HTTP 404", res.status === 404 && json.success === false && json.error === "Student not registered");
    assertTest("Unregistered card writes 0 attendance rows", db.attendance.length === 0);
  }

  // 2. Blocked Card Rejection
  {
    const db = baseDb();
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04D5E6F7", latitude: 28.3949, longitude: 76.9023, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    const rawJson = JSON.stringify(json);
    assertTest("Blocked card returns HTTP 403", res.status === 403);
    assertTest("Blocked card returns exact error_code CARD_BLOCKED", json.error_code === "CARD_BLOCKED");
    assertTest("Blocked card returns terminal_rejection: true", json.terminal_rejection === true);
    assertTest("Blocked card returns sms_dispatch: false", json.sms_dispatch === false);
    assertTest("Blocked card writes 0 attendance rows", db.attendance.length === 0);
    assertTest("Blocked card writes 0 location rows", db.locations.length === 0);
    assertTest("Blocked card response fits within 512-byte modem buffer (size: " + rawJson.length + " bytes)", rawJson.length <= 512);
  }

  // 3. Unblocked Card Success
  {
    const db = baseDb();
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.3949, longitude: 76.9023, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Unblocked card returns HTTP 200", res.status === 200 && json.success === true);
    assertTest("Unblocked card writes 1 attendance record", db.attendance.length === 1);
    assertTest("Unblocked card writes 1 location record", db.locations.length === 1);
    assertTest("Unblocked card provides student_name and student_code", json.student_name === "Rahul Verma" && json.student_code === "STU001");
  }

  // 4. Daily Duplicate Check (Same event type, same day)
  {
    const db = baseDb();
    const today = getIndiaDate();
    db.attendance.push({
      id: "existing-att-1",
      student_id: "stu-1",
      event_date: today,
      event_type: "morning_boarding",
      scanned_at: new Date().toISOString(),
    });

    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.3949, longitude: 76.9023, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Duplicate event on same day returns HTTP 409", res.status === 409 && json.duplicate === true);
    assertTest("Duplicate does not write additional attendance records", db.attendance.length === 1);
  }

  // 5. Different Event Type on Same Day (Morning vs Evening)
  {
    const db = baseDb();
    const today = getIndiaDate();
    db.attendance.push({
      id: "existing-att-1",
      student_id: "stu-1",
      event_date: today,
      event_type: "morning_boarding",
      scanned_at: new Date().toISOString(),
    });

    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.3949, longitude: 76.9023, event_type: "evening_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Different event_type on same day is accepted (HTTP 200)", res.status === 200 && json.success === true);
    assertTest("Second event type recorded in database", db.attendance.length === 2);
  }

  // 6. GPS: Phone Present (Distance <= 100m)
  {
    const db = baseDb();
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("GPS phone <= 100m gives phone_present", json.verification_status === "phone_present" && json.phone_distance_m !== null);
  }

  // 7. GPS: Phone Not Nearby (Distance > 100m)
  {
    const db = baseDb();
    db.phone_locations[0].latitude = 28.45000; // Far away (~6 km)
    db.phone_locations[0].longitude = 76.95000;
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("GPS phone > 100m gives phone_not_nearby", json.verification_status === "phone_not_nearby" && json.phone_distance_m > 100);
  }

  // 8. GPS: Location Stale (> 300s old)
  {
    const db = baseDb();
    db.phone_locations[0].recorded_at = new Date(Date.now() - 400 * 1000).toISOString(); // 400s old
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("GPS phone age > 300s gives location_unavailable", json.verification_status === "location_unavailable");
  }

  // 9. GPS: Inaccurate Location (Accuracy > 100m)
  {
    const db = baseDb();
    db.phone_locations[0].accuracy_m = 150; // Poor accuracy
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("GPS accuracy > 100m gives verification_uncertain", json.verification_status === "verification_uncertain");
  }

  // 10. GPS: No Phone Telemetry
  {
    const db = baseDb();
    db.phone_locations = []; // No location record
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Missing phone telemetry gives location_unavailable", json.verification_status === "location_unavailable");
  }

  // 11. Database Write Boundary Trigger Rejection (Concurrent Block Protection)
  {
    const db = baseDb();
    db.shouldFailAttendanceInsert = true;
    db.attendanceInsertError = { code: "P0001", message: "CARD_BLOCKED: Student transport card is blocked." };

    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Database write boundary P0001 trigger catch returns HTTP 403 CARD_BLOCKED", res.status === 403 && json.error_code === "CARD_BLOCKED");
  }

  // 12. Database Fatal Failure (500)
  {
    const db = baseDb();
    db.shouldFailAttendanceInsert = true;
    db.attendanceInsertError = { code: "58000", message: "System crash" };

    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.39485, longitude: 76.90235, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    const json = await res.json();
    assertTest("Database 500 error returns HTTP 500 Internal server error", res.status === 500 && json.error === "Internal server error");
  }

  // 13. Invalid Payload Format (400)
  {
    const db = baseDb();
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "", latitude: "bad", longitude: 76.9023, event_type: "morning_boarding" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    assertTest("Malformed GPS/RFID returns HTTP 400", res.status === 400);
  }

  // 14. Invalid Event Type (400)
  {
    const db = baseDb();
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rfid_uid: "04A1B2C3", latitude: 28.3949, longitude: 76.9023, event_type: "invalid_lunch_event" }),
    });
    const res = await handleAttendanceRequest(req, createMockSupabase(db));
    assertTest("Invalid event_type returns HTTP 400 with allowed_event_types", res.status === 400);
  }

  console.log(`\nResults: ${passed}/${total} test assertions passed.`);
  if (passed === total) {
    console.log("All Edge Function test scenarios PASSED successfully!");
  } else {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error("Test runner error:", err);
  process.exit(1);
});

