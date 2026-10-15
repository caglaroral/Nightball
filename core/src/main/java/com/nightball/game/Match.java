package com.nightball.game;

import com.nightball.physics.CollisionGroups;
import com.nightball.physics.Disc;
import com.nightball.physics.PhysicsWorld;

import java.util.ArrayList;
import java.util.List;

/**
 * Authoritative match simulation. Runs only on the host, one {@link #tick()} per 1/60 s.
 * Movement, kicking and scoring follow Haxball's per-tick game logic.
 */
public final class Match {
    public static final int TICKS_PER_SECOND = 60;
    private static final int GOAL_PAUSE_TICKS = 150;
    private static final int GAME_OVER_TICKS = 5 * TICKS_PER_SECOND;

    public final Stadium stadium;
    public final PlayerPhysics playerPhysics = new PlayerPhysics();
    public final int scoreLimit;
    public final int timeLimitSeconds;

    private final PhysicsWorld world = new PhysicsWorld();
    private final Disc ball;
    private final List<MatchPlayer> players = new ArrayList<MatchPlayer>();

    private MatchState state = MatchState.KICKOFF;
    private int tick;
    private int timeTicks;
    private int stateTimer;
    private int redScore, blueScore;
    private Team kickoffTeam = Team.RED;
    private Team lastScorer = Team.SPECTATOR;

    public Match(Stadium stadium, int scoreLimit, int timeLimitSeconds) {
        this.stadium = stadium;
        this.scoreLimit = scoreLimit;
        this.timeLimitSeconds = timeLimitSeconds;
        world.planes.addAll(stadium.planes);
        world.segments.addAll(stadium.segments);
        world.vertices.addAll(stadium.vertices);
        ball = new Disc(0f, 0f, 10f, 1f, 0.99f, 0.5f,
                CollisionGroups.BALL | CollisionGroups.KICK | CollisionGroups.SCORE, CollisionGroups.ALL);
        world.discs.add(ball);
        world.discs.addAll(stadium.posts);
    }

    public MatchPlayer addPlayer(int id, Team team) {
        if (team == Team.SPECTATOR || player(id) != null) {
            return null;
        }
        PlayerPhysics p = playerPhysics;
        int mask = CollisionGroups.BALL | CollisionGroups.RED | CollisionGroups.BLUE | CollisionGroups.WALL;
        Disc disc = new Disc(0f, 0f, p.radius, p.invMass, p.damping, p.bCoef, team.collisionGroup, mask);
        MatchPlayer player = new MatchPlayer(id, team, disc);
        players.add(player);
        world.discs.add(disc);
        placeAtSpawn(player, countTeam(team) - 1);
        return player;
    }

    public void removePlayer(int id) {
        MatchPlayer player = player(id);
        if (player != null) {
            players.remove(player);
            world.discs.remove(player.disc);
        }
    }

    public MatchPlayer player(int id) {
        for (int i = 0; i < players.size(); i++) {
            if (players.get(i).id == id) {
                return players.get(i);
            }
        }
        return null;
    }

    public void setInput(int id, float moveX, float moveY, boolean kick) {
        MatchPlayer player = player(id);
        if (player != null) {
            player.setInput(moveX, moveY, kick);
        }
    }

    public void tick() {
        tick++;
        PlayerPhysics p = playerPhysics;
        for (int i = 0; i < players.size(); i++) {
            MatchPlayer player = players.get(i);
            Disc disc = player.disc;
            if (player.kicking && tryKick(disc)) {
                player.kicking = false;
            }
            float acceleration = player.kicking ? p.kickingAcceleration : p.acceleration;
            disc.vx += player.moveX * acceleration;
            disc.vy += player.moveY * acceleration;
            disc.damping = player.kicking ? p.kickingDamping : p.damping;
        }

        float ballX = ball.x;
        float ballY = ball.y;
        world.step();

        switch (state) {
            case KICKOFF:
                holdKickoffPositions();
                if (ball.speedSquared() > 0f) {
                    state = MatchState.PLAYING;
                }
                break;
            case PLAYING:
                timeTicks++;
                Team goal = stadium.goalCrossed(ballX, ballY, ball.x, ball.y);
                if (goal != null) {
                    scoreAgainst(goal);
                } else if (timeLimitSeconds > 0 && timeTicks >= timeLimitSeconds * TICKS_PER_SECOND
                        && redScore != blueScore) {
                    finish();
                }
                break;
            case GOAL:
                if (--stateTimer <= 0) {
                    if (scoreLimit > 0 && (redScore >= scoreLimit || blueScore >= scoreLimit)) {
                        finish();
                    } else {
                        resetPositions();
                    }
                }
                break;
            case OVER:
                stateTimer--;
                break;
        }
    }

    /** Pushes the ball away if it is within reach. Returns whether the kick landed. */
    private boolean tryKick(Disc kicker) {
        PlayerPhysics p = playerPhysics;
        float dx = ball.x - kicker.x;
        float dy = ball.y - kicker.y;
        float dist = (float) Math.sqrt(dx * dx + dy * dy);
        if (dist == 0f || dist - ball.radius - kicker.radius >= p.kickReach) {
            return false;
        }
        float nx = dx / dist;
        float ny = dy / dist;
        ball.vx += nx * p.kickStrength * ball.invMass;
        ball.vy += ny * p.kickStrength * ball.invMass;
        kicker.vx -= nx * p.kickback * kicker.invMass;
        kicker.vy -= ny * p.kickback * kicker.invMass;
        return true;
    }

    private void scoreAgainst(Team defending) {
        Team scorer = defending.opponent();
        if (scorer == Team.RED) {
            redScore++;
        } else {
            blueScore++;
        }
        lastScorer = scorer;
        kickoffTeam = defending;
        state = MatchState.GOAL;
        stateTimer = GOAL_PAUSE_TICKS;
    }

    private void finish() {
        state = MatchState.OVER;
        stateTimer = GAME_OVER_TICKS;
    }

    /** Ball back to the centre and every team back to its own half. */
    public void resetPositions() {
        ball.setPosition(0f, 0f);
        ball.stop();
        int red = 0;
        int blue = 0;
        for (int i = 0; i < players.size(); i++) {
            MatchPlayer player = players.get(i);
            placeAtSpawn(player, player.team == Team.RED ? red++ : blue++);
        }
        state = MatchState.KICKOFF;
    }

    private void placeAtSpawn(MatchPlayer player, int indexInTeam) {
        // 0, -55, +55, -110, +110 ... along the spawn line.
        int row = (indexInTeam + 1) / 2;
        float y = (indexInTeam % 2 == 1 ? -1 : 1) * row * 55f;
        player.disc.setPosition(player.team.side() * stadium.spawnDistance, y);
        player.disc.stop();
    }

    /**
     * Before the kickoff both teams stay in their own half. The team taking the kickoff may also
     * enter the centre circle; the other team must stay out of it.
     */
    private void holdKickoffPositions() {
        float circle = stadium.kickoffRadius;
        for (int i = 0; i < players.size(); i++) {
            MatchPlayer player = players.get(i);
            Disc d = player.disc;
            float side = player.team.side();
            float r = d.radius;
            float dist = (float) Math.sqrt(d.x * d.x + d.y * d.y);
            if (player.team == kickoffTeam) {
                boolean inOwnHalf = side * d.x >= r;
                boolean inCircle = dist + r <= circle;
                if (!inOwnHalf && !inCircle) {
                    float toHalf = r - side * d.x;
                    float toCircle = dist + r - circle;
                    if (toHalf <= toCircle || dist == 0f) {
                        pushTo(d, side * r, d.y);
                    } else {
                        float scale = (circle - r) / dist;
                        pushTo(d, d.x * scale, d.y * scale);
                    }
                }
            } else {
                if (side * d.x < r) {
                    pushTo(d, side * r, d.y);
                }
                dist = (float) Math.sqrt(d.x * d.x + d.y * d.y);
                if (dist < circle + r && dist > 0f) {
                    float scale = (circle + r) / dist;
                    pushTo(d, d.x * scale, d.y * scale);
                }
            }
        }
    }

    /** Moves a disc and removes the velocity component that pushed it out. */
    private static void pushTo(Disc d, float x, float y) {
        float nx = x - d.x;
        float ny = y - d.y;
        float length = (float) Math.sqrt(nx * nx + ny * ny);
        d.setPosition(x, y);
        if (length > 0f) {
            nx /= length;
            ny /= length;
            float into = d.vx * nx + d.vy * ny;
            if (into < 0f) {
                d.vx -= nx * into;
                d.vy -= ny * into;
            }
        }
    }

    private int countTeam(Team team) {
        int count = 0;
        for (int i = 0; i < players.size(); i++) {
            if (players.get(i).team == team) {
                count++;
            }
        }
        return count;
    }

    public void writeSnapshot(Snapshot out) {
        out.tick = tick;
        out.state = state;
        out.redScore = redScore;
        out.blueScore = blueScore;
        out.timeTicks = timeTicks;
        out.timeLimitSeconds = timeLimitSeconds;
        out.kickoffTeam = kickoffTeam;
        out.lastScorer = lastScorer;
        out.ballX = ball.x;
        out.ballY = ball.y;
        int count = Math.min(players.size(), Snapshot.MAX_PLAYERS);
        out.playerCount = count;
        for (int i = 0; i < count; i++) {
            MatchPlayer player = players.get(i);
            out.playerIds[i] = player.id;
            out.playerTeams[i] = player.team;
            out.playerX[i] = player.disc.x;
            out.playerY[i] = player.disc.y;
            out.playerKicking[i] = player.kicking;
        }
    }

    public MatchState state() {
        return state;
    }

    /** True once the result screen has been shown long enough. */
    public boolean isFinished() {
        return state == MatchState.OVER && stateTimer <= 0;
    }

    public Disc ball() {
        return ball;
    }

    public int redScore() {
        return redScore;
    }

    public int blueScore() {
        return blueScore;
    }
}
