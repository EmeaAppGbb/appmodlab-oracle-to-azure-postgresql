package com.skyreward.repository;

import com.skyreward.model.Reward;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA repository for Reward entities.
 */
@Repository
public interface RewardRepository extends JpaRepository<Reward, Integer> {

    Optional<Reward> findByRewardCode(String rewardCode);

    List<Reward> findByCategoryAndStatus(String category, String status);

    List<Reward> findByStatus(String status);
}
