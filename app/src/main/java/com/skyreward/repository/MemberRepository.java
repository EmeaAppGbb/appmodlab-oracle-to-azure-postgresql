package com.skyreward.repository;

import com.skyreward.model.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA repository for Member entities.
 *
 * Migration notes:
 * - Oracle-specific CONNECT BY or ROWNUM-based queries replaced with
 *   standard JPQL or PostgreSQL-compatible native queries.
 * - Oracle's UPPER() and LIKE patterns work identically in PostgreSQL.
 */
@Repository
public interface MemberRepository extends JpaRepository<Member, Integer> {

    Optional<Member> findByEmail(String email);

    Optional<Member> findByMembershipNumber(String membershipNumber);

    List<Member> findByLastNameIgnoreCaseStartingWithAndStatus(String lastName, String status);

    @Query("SELECT m FROM Member m WHERE UPPER(m.lastName) LIKE UPPER(CONCAT(:lastName, '%')) " +
           "AND (:firstName IS NULL OR UPPER(m.firstName) LIKE UPPER(CONCAT(:firstName, '%'))) " +
           "AND m.status = 'ACTIVE' ORDER BY m.lastName, m.firstName")
    List<Member> searchMembers(@Param("lastName") String lastName,
                               @Param("firstName") String firstName);

    List<Member> findByTierStatus(String tierStatus);

    List<Member> findByStatus(String status);
}
