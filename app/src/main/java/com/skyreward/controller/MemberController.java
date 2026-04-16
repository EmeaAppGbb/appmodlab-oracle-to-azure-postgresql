package com.skyreward.controller;

import com.skyreward.model.Flight;
import com.skyreward.model.Member;
import com.skyreward.model.Redemption;
import com.skyreward.service.MemberService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * REST controller for member operations.
 *
 * Demonstrates how the application layer remains largely unchanged
 * after migrating from Oracle to PostgreSQL — the service layer
 * abstracts the database-specific function calls.
 */
@RestController
@RequestMapping("/api/members")
public class MemberController {

    private final MemberService memberService;

    public MemberController(MemberService memberService) {
        this.memberService = memberService;
    }

    // =========================================================================
    // Member CRUD endpoints
    // =========================================================================

    @GetMapping("/{memberId}")
    public ResponseEntity<Member> getMember(@PathVariable Integer memberId) {
        return memberService.findById(memberId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/by-email")
    public ResponseEntity<Member> getMemberByEmail(@RequestParam String email) {
        return memberService.findByEmail(email)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/by-membership")
    public ResponseEntity<Member> getMemberByMembershipNumber(@RequestParam String number) {
        return memberService.findByMembershipNumber(number)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/search")
    public ResponseEntity<List<Member>> searchMembers(
            @RequestParam String lastName,
            @RequestParam(required = false) String firstName) {
        List<Member> results = memberService.searchMembers(lastName, firstName);
        return ResponseEntity.ok(results);
    }

    // =========================================================================
    // PL/pgSQL function endpoints
    // =========================================================================

    /**
     * Register a new member via the PL/pgSQL function.
     * POST /api/members/register
     */
    @PostMapping("/register")
    public ResponseEntity<Map<String, Object>> registerMember(@RequestBody Map<String, String> request) {
        Map<String, Object> result = memberService.registerMember(
                request.get("firstName"),
                request.get("lastName"),
                request.get("email"),
                request.get("phone"),
                request.getOrDefault("country", "US")
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    /**
     * Get member details via the PL/pgSQL function.
     * GET /api/members/{memberId}/details
     */
    @GetMapping("/{memberId}/details")
    public ResponseEntity<Map<String, Object>> getMemberDetails(@PathVariable Integer memberId) {
        Map<String, Object> details = memberService.getMemberDetails(memberId);
        return ResponseEntity.ok(details);
    }

    /**
     * Get tier status via the PL/pgSQL function.
     * GET /api/members/{memberId}/tier-status
     */
    @GetMapping("/{memberId}/tier-status")
    public ResponseEntity<Map<String, String>> getTierStatus(@PathVariable Integer memberId) {
        String status = memberService.getTierStatus(memberId);
        return ResponseEntity.ok(Map.of("tierStatus", status));
    }

    /**
     * Calculate miles via the PL/pgSQL function.
     * GET /api/members/calculate-miles
     */
    @GetMapping("/calculate-miles")
    public ResponseEntity<Map<String, Object>> calculateMiles(
            @RequestParam int distance,
            @RequestParam String bookingClass,
            @RequestParam String cabinClass,
            @RequestParam(defaultValue = "BLUE") String tier) {
        BigDecimal miles = memberService.calculateMiles(distance, bookingClass, cabinClass, tier);
        return ResponseEntity.ok(Map.of("calculatedMiles", miles));
    }

    /**
     * Update member profile via the PL/pgSQL function.
     * PUT /api/members/{memberId}/profile
     */
    @PutMapping("/{memberId}/profile")
    public ResponseEntity<Void> updateProfile(
            @PathVariable Integer memberId,
            @RequestBody Map<String, String> request) {
        memberService.updateMemberProfile(
                memberId,
                request.get("firstName"),
                request.get("lastName"),
                request.get("email"),
                request.get("phone")
        );
        return ResponseEntity.noContent().build();
    }

    // =========================================================================
    // Flight endpoints
    // =========================================================================

    /**
     * Get flights for a member.
     * GET /api/members/{memberId}/flights
     */
    @GetMapping("/{memberId}/flights")
    public ResponseEntity<List<Flight>> getMemberFlights(@PathVariable Integer memberId) {
        List<Flight> flights = memberService.getMemberFlights(memberId);
        return ResponseEntity.ok(flights);
    }

    /**
     * Record a flight via the PL/pgSQL function.
     * POST /api/members/{memberId}/flights
     */
    @PostMapping("/{memberId}/flights")
    public ResponseEntity<Map<String, Object>> recordFlight(
            @PathVariable Integer memberId,
            @RequestBody Map<String, Object> request) {
        Long flightId = memberService.recordFlight(
                memberId,
                (String) request.get("flightNumber"),
                (String) request.get("airlineCode"),
                (String) request.get("departure"),
                (String) request.get("arrival"),
                LocalDate.parse((String) request.get("flightDate")),
                (String) request.get("bookingClass"),
                (String) request.get("cabinClass"),
                ((Number) request.get("distanceMiles")).intValue()
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("flightId", flightId));
    }

    // =========================================================================
    // Redemption endpoints
    // =========================================================================

    /**
     * Get redemptions for a member.
     * GET /api/members/{memberId}/redemptions
     */
    @GetMapping("/{memberId}/redemptions")
    public ResponseEntity<List<Redemption>> getMemberRedemptions(@PathVariable Integer memberId) {
        List<Redemption> redemptions = memberService.getMemberRedemptions(memberId);
        return ResponseEntity.ok(redemptions);
    }

    /**
     * Redeem a reward via the PL/pgSQL function.
     * POST /api/members/{memberId}/redemptions
     */
    @PostMapping("/{memberId}/redemptions")
    public ResponseEntity<Map<String, Object>> redeemReward(
            @PathVariable Integer memberId,
            @RequestBody Map<String, Object> request) {
        Map<String, Object> result = memberService.redeemReward(
                memberId,
                ((Number) request.get("rewardId")).intValue(),
                request.containsKey("quantity") ? ((Number) request.get("quantity")).intValue() : 1,
                (String) request.getOrDefault("channel", "WEB")
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }
}
