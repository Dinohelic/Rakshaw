import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};


// =====================================================
// PHONE VERIFICATION SETTINGS
// =====================================================

const PHONE_NEARBY_DISTANCE_M = 100;
const PHONE_LOCATION_MAX_AGE_SECONDS = 300;
const PHONE_MAX_ACCURACY_M = 100;


const VALID_EVENT_TYPES = [
  "morning_boarding",
  "evening_boarding",
  "deboarding",
];


// =====================================================
// INDIA DATE
// =====================================================

function getIndiaDate(): string {

  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());

  const year =
    parts.find((p) => p.type === "year")?.value;

  const month =
    parts.find((p) => p.type === "month")?.value;

  const day =
    parts.find((p) => p.type === "day")?.value;

  return `${year}-${month}-${day}`;
}


// =====================================================
// EVENT MESSAGE
// =====================================================

function getEventMessage(
  eventType: string,
): string {

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


// =====================================================
// HAVERSINE DISTANCE
// =====================================================

function calculateDistanceMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {

  const earthRadiusM = 6371000;

  const toRadians = (
    degrees: number,
  ) => degrees * Math.PI / 180;


  const latitude1 =
    toRadians(lat1);

  const latitude2 =
    toRadians(lat2);

  const deltaLatitude =
    toRadians(lat2 - lat1);

  const deltaLongitude =
    toRadians(lon2 - lon1);


  const a =
    Math.sin(deltaLatitude / 2) *
    Math.sin(deltaLatitude / 2) +

    Math.cos(latitude1) *
    Math.cos(latitude2) *

    Math.sin(deltaLongitude / 2) *
    Math.sin(deltaLongitude / 2);


  const c =
    2 *
    Math.atan2(
      Math.sqrt(a),
      Math.sqrt(1 - a),
    );


  return earthRadiusM * c;
}


// =====================================================
// EDGE FUNCTION
// =====================================================

Deno.serve(async (req) => {

  // ---------------------------------------------------
  // CORS
  // ---------------------------------------------------

  if (req.method === "OPTIONS") {

    return new Response(
      "ok",
      {
        headers: corsHeaders,
      },
    );
  }


  if (req.method !== "POST") {

    return Response.json(
      {
        success: false,
        error: "POST required",
      },
      {
        status: 405,
        headers: corsHeaders,
      },
    );
  }


  try {

    // =================================================
    // READ ESP32 REQUEST
    // =================================================

    const body =
      await req.json();


    const rfidUid =
      String(
        body.rfid_uid ?? "",
      )
        .replace(/\s+/g, "")
        .toUpperCase();


    const latitude =
      Number(
        body.latitude,
      );


    const longitude =
      Number(
        body.longitude,
      );


    const deviceId =
      String(
        body.device_id ??
        "RAKSHA-ESP32-001",
      );


    const eventType =
      String(
        body.event_type ?? "",
      )
        .trim()
        .toLowerCase();


    // =================================================
    // VALIDATE RFID + BUS GPS
    // =================================================

    if (
      !rfidUid ||

      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||

      latitude < -90 ||
      latitude > 90 ||

      longitude < -180 ||
      longitude > 180
    ) {

      return Response.json(
        {
          success: false,
          error:
            "Invalid RFID or GPS data",
        },
        {
          status: 400,
          headers: corsHeaders,
        },
      );
    }


    // =================================================
    // VALIDATE EVENT
    // =================================================

    if (
      !VALID_EVENT_TYPES.includes(
        eventType,
      )
    ) {

      return Response.json(
        {
          success: false,
          error:
            "Invalid event type",

          allowed_event_types:
            VALID_EVENT_TYPES,
        },
        {
          status: 400,
          headers: corsHeaders,
        },
      );
    }


    // =================================================
    // SUPABASE
    // =================================================

    const supabaseUrl =
      Deno.env.get(
        "SUPABASE_URL",
      );


    const serviceKey =
      Deno.env.get(
        "SUPABASE_SERVICE_ROLE_KEY",
      );


    if (
      !supabaseUrl ||
      !serviceKey
    ) {

      throw new Error(
        "Supabase environment variables missing",
      );
    }


    const supabase =
      createClient(
        supabaseUrl,
        serviceKey,
      );


    // =================================================
    // FIND STUDENT FROM RFID
    // =================================================

    const {
      data: student,
      error: studentError,
    } = await supabase
      .from("students")
      .select(
        "id, student_code, student_name",
      )
      .eq(
        "rfid_uid",
        rfidUid,
      )
      .maybeSingle();


    if (studentError) {
      throw studentError;
    }


    if (!student) {

      return Response.json(
        {
          success: false,
          error:
            "Student not registered",
        },
        {
          status: 404,
          headers: corsHeaders,
        },
      );
    }


    // =================================================
    // TIME
    // =================================================

    const now =
      new Date();


    const scannedAt =
      now.toISOString();


    const eventDate =
      getIndiaDate();


    // =================================================
    // DUPLICATE CHECK
    // =================================================

    const {
      data: existingAttendance,
      error: duplicateCheckError,
    } = await supabase
      .from("attendance")
      .select(
        "id, scanned_at, event_type",
      )
      .eq(
        "student_id",
        student.id,
      )
      .eq(
        "event_date",
        eventDate,
      )
      .eq(
        "event_type",
        eventType,
      )
      .maybeSingle();


    if (duplicateCheckError) {
      throw duplicateCheckError;
    }


    if (existingAttendance) {

      return Response.json(
        {
          success: false,
          duplicate: true,
          error:
            "Event already recorded",

          student_code:
            student.student_code,

          student_name:
            student.student_name,

          event_type:
            eventType,

          event_date:
            eventDate,

          existing_attendance_id:
            existingAttendance.id,

          original_scanned_at:
            existingAttendance.scanned_at,
        },
        {
          status: 409,
          headers: corsHeaders,
        },
      );
    }


    // =================================================
    // GET STUDENT PHONE LOCATION
    // =================================================

    const {
      data: phoneLocation,
      error: phoneLocationError,
    } = await supabase
      .from(
        "student_phone_locations",
      )
      .select(
        `
        latitude,
        longitude,
        accuracy_m,
        recorded_at,
        phone_device_id
        `,
      )
      .eq(
        "student_id",
        student.id,
      )
      .maybeSingle();


    if (phoneLocationError) {
      throw phoneLocationError;
    }


    // =================================================
    // PHONE VERIFICATION DEFAULTS
    // =================================================

    let verificationStatus =
      "location_unavailable";


    let phoneDistanceM:
      number | null = null;


    let phoneLocationAt:
      string | null = null;


    let phoneLocationAgeSeconds:
      number | null = null;


    let phoneAccuracyM:
      number | null = null;


    // =================================================
    // VERIFY PHONE
    // =================================================

    if (phoneLocation) {

      phoneLocationAt =
        phoneLocation.recorded_at;


      if (
        phoneLocation.accuracy_m !== null
      ) {

        phoneAccuracyM =
          Number(
            phoneLocation.accuracy_m,
          );
      }


      const phoneTime =
        new Date(
          phoneLocation.recorded_at,
        );


      phoneLocationAgeSeconds =
        Math.max(
          0,
          Math.floor(
            (
              now.getTime() -
              phoneTime.getTime()
            ) / 1000,
          ),
        );


      // -----------------------------------------------
      // OLD LOCATION
      // -----------------------------------------------

      if (
        phoneLocationAgeSeconds >
        PHONE_LOCATION_MAX_AGE_SECONDS
      ) {

        verificationStatus =
          "location_unavailable";
      }


      // -----------------------------------------------
      // POOR GPS ACCURACY
      // -----------------------------------------------

      else if (
        phoneAccuracyM !== null &&
        phoneAccuracyM >
        PHONE_MAX_ACCURACY_M
      ) {

        verificationStatus =
          "verification_uncertain";
      }


      // -----------------------------------------------
      // LOCATION USABLE
      // -----------------------------------------------

      else {

        phoneDistanceM =
          calculateDistanceMeters(

            latitude,
            longitude,

            Number(
              phoneLocation.latitude,
            ),

            Number(
              phoneLocation.longitude,
            ),
          );


        if (
          phoneDistanceM <=
          PHONE_NEARBY_DISTANCE_M
        ) {

          verificationStatus =
            "phone_present";

        } else {

          verificationStatus =
            "phone_not_nearby";
        }
      }
    }


    // =================================================
    // SERIAL / FUNCTION LOG
    // =================================================

    console.log(
      "Student:",
      student.student_code,
    );

    console.log(
      "Verification:",
      verificationStatus,
    );

    console.log(
      "Phone distance:",
      phoneDistanceM,
    );

    console.log(
      "Phone age:",
      phoneLocationAgeSeconds,
    );


    // =================================================
    // INSERT ATTENDANCE
    // =================================================

    const {
      data: attendance,
      error: attendanceError,
    } = await supabase
      .from("attendance")
      .insert({

        student_id:
          student.id,

        attendance_status:
          "present",

        scanned_at:
          scannedAt,

        latitude,

        longitude,

        device_id:
          deviceId,

        event_type:
          eventType,

        event_date:
          eventDate,


        // ---------------------------------------------
        // PHONE VERIFICATION
        // ---------------------------------------------

        verification_status:
          verificationStatus,

        phone_distance_m:
          phoneDistanceM,

        phone_location_at:
          phoneLocationAt,

        phone_location_age_seconds:
          phoneLocationAgeSeconds,

        phone_accuracy_m:
          phoneAccuracyM,

      })
      .select(
        `
        id,
        scanned_at,
        event_type,
        event_date,
        verification_status,
        phone_distance_m,
        phone_location_age_seconds,
        phone_accuracy_m
        `,
      )
      .single();


    // =================================================
    // DATABASE DUPLICATE SAFETY
    // =================================================

    if (attendanceError) {

      if (
        attendanceError.code ===
        "23505"
      ) {

        return Response.json(
          {
            success: false,
            duplicate: true,

            error:
              "Event already recorded",

            student_code:
              student.student_code,

            student_name:
              student.student_name,

            event_type:
              eventType,

            event_date:
              eventDate,
          },
          {
            status: 409,
            headers: corsHeaders,
          },
        );
      }


      throw attendanceError;
    }


    // =================================================
    // SAVE BUS LOCATION
    // =================================================

    const {
      error: locationError,
    } = await supabase
      .from("locations")
      .insert({

        student_id:
          student.id,

        latitude,

        longitude,

        recorded_at:
          scannedAt,

        device_id:
          deviceId,
      });


    if (locationError) {
      throw locationError;
    }


    // =================================================
    // SUCCESS RESPONSE
    // =================================================

    return Response.json(
      {
        success: true,

        message:
          getEventMessage(
            eventType,
          ),

        student_code:
          student.student_code,

        student_name:
          student.student_name,

        event_type:
          attendance.event_type,

        event_date:
          attendance.event_date,

        attendance_id:
          attendance.id,

        scanned_at:
          attendance.scanned_at,


        // ---------------------------------------------
        // PHONE VERIFICATION RESULT
        // ---------------------------------------------

        verification_status:
          attendance.verification_status,

        phone_distance_m:
          attendance.phone_distance_m,

        phone_location_age_seconds:
          attendance.phone_location_age_seconds,

        phone_accuracy_m:
          attendance.phone_accuracy_m,
      },
      {
        status: 200,
        headers: corsHeaders,
      },
    );


  } catch (error) {

    console.error(error);


    return Response.json(
      {
        success: false,
        error:
          "Internal server error",
      },
      {
        status: 500,
        headers: corsHeaders,
      },
    );
  }
});

