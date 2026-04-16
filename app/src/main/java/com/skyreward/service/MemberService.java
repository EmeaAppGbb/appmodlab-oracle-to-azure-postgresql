package com.skyreward.service;

import com.skyreward.model.Flight;
import com.skyreward.model.Member;
import com.skyreward.model.Redemption;
import com.skyreward.repository.FlightRepository;
import com.skyreward.repository.MemberRepository;
import com.skyreward.repository.RedemptionRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Service layer demonstrating key PostgreSQL function calls.
 *
 * <h2>Migration patterns demonstrated here</h2>
 * <ul>
 *   <li><b>Oracle package calls → PostgreSQL standalone functions</b>:
 *       Oracle's {@code PKG_MEMBER_MGMT.register_member(...)} becomes
 *       {@code SELECT * FROM member_mgmt_register_member(...)}.</li>
 *   <li><b>Oracle REF CURSOR OUT params → PostgreSQL RETURNS TABLE</b>:
 *       Results come back as a standard JDBC ResultSet.</li>
 *   <li><b>RAISE_APPLICATION_ERROR → RAISE EXCEPTION</b>:
 *       PostgreSQL exceptions surface as {@code org.postgresql.util.PSQLException}
 *       (mapped to {@code org.springframework.dao.DataAccessException} by Spring).</li>
 *   <li><b>Native query syntax</b>: {@code SELECT fn_calculate_miles(:dist, :bc, :cc, :tier)}
 *       uses PostgreSQL's {@code $n} or named-param binding.</li>
 * </ul>
 */
@Service
@Transactional
public class MemberService {

    private final MemberRepository memberRepository;
    private final FlightRepository flightRepository;
    private final RedemptionRepository redemptionRepository;

    @PersistenceContext
    private EntityManager entityManager;

    public MemberService(MemberRepository memberRepository,
                         FlightRepository flightRepository,
                         RedemptionRepository redemptionRepository) {
        this.memberRepository = memberRepository;
        this.flightRepository = flightRepository;
        this.redemptionRepository = redemptionRepository;
    }

    // =========================================================================
    // CRUD operations via Spring Data JPA
    // =========================================================================

    @Transactional(readOnly = true)
    public Optional<Member> findById(Integer memberId) {
        return memberRepository.findById(memberId);
    }

    @Transactional(readOnly = true)
    public Optional<Member> findByEmail(String email) {
        return memberRepository.findByEmail(email);
    }

    @Transactional(readOnly = true)
    public Optional<Member> findByMembershipNumber(String membershipNumber) {
        return memberRepository.findByMembershipNumber(membershipNumber);
    }

    @Transactional(readOnly = true)
    public List<Member> searchMembers(String lastName, String firstName) {
        return memberRepository.searchMembers(lastName, firstName);
    }

    @Transactional(readOnly = true)
    public List<Flight> getMemberFlights(Integer memberId) {
        return flightRepository.findByMemberMemberIdOrderByFlightDateDesc(memberId);
    }

    @Transactional(readOnly = true)
    public List<Redemption> getMemberRedemptions(Integer memberId) {
        return redemptionRepository.findByMemberMemberIdOrderByRedemptionDateDesc(memberId);
    }

    // =========================================================================
    // Calling PostgreSQL PL/pgSQL functions via native queries
    // =========================================================================
    // These demonstrate calling the migrated PL/pgSQL functions that replaced
    // Oracle PL/SQL packages. The key migration pattern:
    //
    //   ORACLE:      {? = call PKG_MEMBER_MGMT.register_member(?, ?, ?, ...)}
    //   POSTGRESQL:  SELECT * FROM member_mgmt_register_member(?, ?, ?, ...)
    //
    // Spring's EntityManager native queries handle this cleanly.
    // =========================================================================

    /**
     * Register a new member by calling the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   PKG_MEMBER_MGMT.register_member(p_first_name, p_last_name, p_email, ...)
     *
     * PostgreSQL:
     *   SELECT * FROM member_mgmt_register_member(...)
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> registerMember(String firstName, String lastName,
                                               String email, String phone,
                                               String country) {
        Object[] result = (Object[]) entityManager.createNativeQuery(
                "SELECT * FROM member_mgmt_register_member(:firstName, :lastName, :email, :phone, NULL, :country)")
                .setParameter("firstName", firstName)
                .setParameter("lastName", lastName)
                .setParameter("email", email)
                .setParameter("phone", phone)
                .setParameter("country", country != null ? country : "US")
                .getSingleResult();

        return Map.of(
                "memberId", result[0],
                "membershipNumber", result[1]
        );
    }

    /**
     * Get tier status by calling the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   fn_get_tier_status(p_member_id)
     *
     * PostgreSQL (identical function name, different internal syntax):
     *   SELECT fn_get_tier_status(?)
     */
    @Transactional(readOnly = true)
    public String getTierStatus(Integer memberId) {
        return (String) entityManager.createNativeQuery(
                "SELECT fn_get_tier_status(:memberId)")
                .setParameter("memberId", memberId)
                .getSingleResult();
    }

    /**
     * Calculate miles using the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   fn_calculate_miles(p_distance, p_booking_class, p_cabin_class, p_tier)
     *
     * PostgreSQL:
     *   SELECT fn_calculate_miles(?, ?, ?, ?)
     */
    @Transactional(readOnly = true)
    public BigDecimal calculateMiles(int distanceMiles, String bookingClass,
                                     String cabinClass, String memberTier) {
        return (BigDecimal) entityManager.createNativeQuery(
                "SELECT fn_calculate_miles(:distance, :bookingClass, :cabinClass, :tier)")
                .setParameter("distance", distanceMiles)
                .setParameter("bookingClass", bookingClass)
                .setParameter("cabinClass", cabinClass)
                .setParameter("tier", memberTier != null ? memberTier : "BLUE")
                .getSingleResult();
    }

    /**
     * Record a flight by calling the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   PKG_FLIGHT_ACCRUAL.record_flight(p_member_id, ..., p_flight_id OUT)
     *
     * PostgreSQL (OUT param becomes RETURNS BIGINT):
     *   SELECT flight_accrual_record_flight(...)
     */
    public Long recordFlight(Integer memberId, String flightNumber, String airlineCode,
                             String departure, String arrival, java.time.LocalDate flightDate,
                             String bookingClass, String cabinClass, int distanceMiles) {
        return ((Number) entityManager.createNativeQuery(
                "SELECT flight_accrual_record_flight(" +
                        ":memberId, :flightNumber, :airlineCode, " +
                        ":departure, :arrival, :flightDate, " +
                        ":bookingClass, :cabinClass, :distanceMiles)")
                .setParameter("memberId", memberId)
                .setParameter("flightNumber", flightNumber)
                .setParameter("airlineCode", airlineCode)
                .setParameter("departure", departure)
                .setParameter("arrival", arrival)
                .setParameter("flightDate", flightDate)
                .setParameter("bookingClass", bookingClass)
                .setParameter("cabinClass", cabinClass)
                .setParameter("distanceMiles", distanceMiles)
                .getSingleResult()).longValue();
    }

    /**
     * Redeem a reward by calling the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   PKG_REDEMPTION_MGMT.redeem_reward(p_member_id, p_reward_id, ...)
     *
     * PostgreSQL:
     *   SELECT * FROM redemption_mgmt_redeem_reward(...)
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> redeemReward(Integer memberId, Integer rewardId,
                                             int quantity, String channel) {
        Object[] result = (Object[]) entityManager.createNativeQuery(
                "SELECT * FROM redemption_mgmt_redeem_reward(:memberId, :rewardId, :quantity, :channel)")
                .setParameter("memberId", memberId)
                .setParameter("rewardId", rewardId)
                .setParameter("quantity", quantity)
                .setParameter("channel", channel != null ? channel : "WEB")
                .getSingleResult();

        return Map.of(
                "redemptionId", result[0],
                "confirmationCode", result[1]
        );
    }

    /**
     * Update a member profile by calling the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   PKG_MEMBER_MGMT.update_member_profile(p_member_id, ...)
     *
     * PostgreSQL:
     *   SELECT member_mgmt_update_member_profile(...)
     */
    public void updateMemberProfile(Integer memberId, String firstName, String lastName,
                                     String email, String phone) {
        entityManager.createNativeQuery(
                "SELECT member_mgmt_update_member_profile(:memberId, :firstName, :lastName, :email, :phone)")
                .setParameter("memberId", memberId)
                .setParameter("firstName", firstName)
                .setParameter("lastName", lastName)
                .setParameter("email", email)
                .setParameter("phone", phone)
                .getSingleResult();
    }

    /**
     * Get member details by calling the PL/pgSQL function.
     *
     * Oracle equivalent:
     *   PKG_MEMBER_MGMT.get_member(p_member_id)
     *
     * PostgreSQL:
     *   SELECT * FROM member_mgmt_get_member(?)
     */
    @SuppressWarnings("unchecked")
    @Transactional(readOnly = true)
    public Map<String, Object> getMemberDetails(Integer memberId) {
        Object[] result = (Object[]) entityManager.createNativeQuery(
                "SELECT * FROM member_mgmt_get_member(:memberId)")
                .setParameter("memberId", memberId)
                .getSingleResult();

        return Map.of(
                "memberId", result[0],
                "membershipNumber", result[1],
                "firstName", result[2],
                "lastName", result[3],
                "email", result[4],
                "tierStatus", result[5],
                "availableMiles", result[6]
        );
    }
}
