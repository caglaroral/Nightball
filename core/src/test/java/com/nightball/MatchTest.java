package com.nightball;

import com.nightball.game.Match;
import com.nightball.game.MatchPlayer;
import com.nightball.game.MatchState;
import com.nightball.game.Stadium;
import com.nightball.game.Team;
import com.nightball.physics.Disc;
import com.nightball.physics.PhysicsWorld;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class MatchTest {

    @Test
    public void playerReachesHaxballTopSpeed() {
        Match match = new Match(Stadium.classic(), 3, 0);
        MatchPlayer player = match.addPlayer(1, Team.RED);
        match.resetPositions();
        // Stays in its own half for the whole run, so the kickoff rule does not interfere.
        player.disc.setPosition(-400f, 0f);
        for (int i = 0; i < 150; i++) {
            match.setInput(1, 1f, 0f, false);
            match.tick();
        }
        // Terminal speed of v' = (v + a) * d is a*d / (1 - d) = 0.1 * 0.96 / 0.04 = 2.4 px/tick.
        assertEquals(2.4f, (float) Math.sqrt(player.disc.speedSquared()), 0.01f);
    }

    @Test
    public void diagonalMovementIsNotFaster() {
        MatchPlayer straight = runFor(1f, 0f);
        MatchPlayer diagonal = runFor(1f, 1f);
        assertEquals(straight.disc.speedSquared(), diagonal.disc.speedSquared(), 1e-3f);
    }

    private MatchPlayer runFor(float x, float y) {
        Match match = new Match(Stadium.classic(), 3, 0);
        MatchPlayer player = match.addPlayer(1, Team.BLUE);
        player.disc.setPosition(200f, 0f);
        for (int i = 0; i < 30; i++) {
            match.setInput(1, x, y, false);
            match.tick();
        }
        return player;
    }

    @Test
    public void kickGivesTheBallKickStrength() {
        Match match = new Match(Stadium.classic(), 3, 0);
        MatchPlayer player = match.addPlayer(1, Team.RED);
        match.resetPositions();
        Disc ball = match.ball();
        // Touching the ball from the left, kick pressed this tick.
        player.disc.setPosition(ball.x - ball.radius - player.disc.radius - 1f, 0f);
        match.setInput(1, 0f, 0f, true);
        match.tick();
        // 5 px/tick added, then one tick of ball damping (0.99).
        assertEquals(5f * 0.99f, ball.vx, 1e-4f);
        assertEquals(0f, ball.vy, 1e-4f);
        assertEquals(MatchState.PLAYING, match.state());
        // Holding the button does not kick again.
        float speed = ball.vx;
        match.setInput(1, 0f, 0f, true);
        match.tick();
        assertTrue(ball.vx < speed);
    }

    @Test
    public void kickoffKeepsDefendersOutOfTheCircleAndHalf() {
        Match match = new Match(Stadium.classic(), 3, 0);
        MatchPlayer red = match.addPlayer(1, Team.RED);
        MatchPlayer blue = match.addPlayer(2, Team.BLUE);
        match.resetPositions();
        // Red takes the first kickoff; blue runs left at full speed and must stop.
        for (int i = 0; i < 300; i++) {
            match.setInput(2, -1f, 0f, false);
            match.tick();
        }
        Disc b = blue.disc;
        assertEquals(MatchState.KICKOFF, match.state());
        assertTrue(b.x >= b.radius - 0.01f);
        assertTrue(Math.sqrt(b.x * b.x + b.y * b.y) >= 75f + b.radius - 0.01f);
        assertTrue(red.disc.x < 0f);
    }

    @Test
    public void ballInTheRightGoalScoresForRed() {
        Match match = new Match(Stadium.classic(), 1, 0);
        match.addPlayer(1, Team.RED);
        match.resetPositions();
        Disc ball = match.ball();
        ball.setPosition(300f, 0f);
        ball.vx = 10f;
        for (int i = 0; i < 30 && match.state() != MatchState.GOAL; i++) {
            match.tick();
        }
        assertEquals(MatchState.GOAL, match.state());
        assertEquals(1, match.redScore());
        assertEquals(0, match.blueScore());
        // Score limit 1: after the goal pause the match is over.
        for (int i = 0; i < 200; i++) {
            match.tick();
        }
        assertEquals(MatchState.OVER, match.state());
    }

    @Test
    public void ballBouncesOffSideLineAndStaysOnPitch() {
        Match match = new Match(Stadium.classic(), 3, 0);
        Disc ball = match.ball();
        // A hard kick plus a running player gives about 7.4 px/tick. Like Haxball, speeds above
        // the ball radius per tick could tunnel through thin walls, but play never reaches them.
        ball.setPosition(0f, 100f);
        ball.vy = 7.4f;
        for (int i = 0; i < 20; i++) {
            match.tick();
        }
        assertTrue(ball.vy < 0f);
        assertTrue(ball.y <= 170f - ball.radius + 0.01f);
    }

    @Test
    public void discCollisionConservesMomentumForEqualMasses() {
        PhysicsWorld world = new PhysicsWorld();
        Disc a = new Disc(0f, 0f, 10f, 1f, 1f, 1f, 1, 1);
        Disc b = new Disc(19f, 0f, 10f, 1f, 1f, 1f, 1, 1);
        a.vx = 2f;
        world.discs.add(a);
        world.discs.add(b);
        world.step();
        // bCoef 1 * 1: a perfectly elastic hit swaps the velocities.
        assertEquals(0f, a.vx, 1e-4f);
        assertEquals(2f, b.vx, 1e-4f);
    }
}
