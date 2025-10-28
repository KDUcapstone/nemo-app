package com.nemo.backend.domain.album.repository;

import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AlbumRepository extends JpaRepository<Album, Long> {
    List<Album> findByUser(User user);
}
