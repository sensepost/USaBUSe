package com.sensepost.hidproxy;

import java.util.List;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.ByteToMessageCodec;

public class PacketCodec extends ByteToMessageCodec<Packet> {

	long epoch = System.currentTimeMillis();
	long lastPrint = epoch;
	long readCount = 0, readSinceLast = 0;
	long writeCount = 0, writeSinceLast = 0;

	private boolean verbose = false;

	/**
	 * Reads bytes from the multiplexed channel, and decodes them into Packets
	 * (adjusting for the case where we are connected directly via a network
	 * socket and receiving 65 bytes, vs connected via the HID, and only
	 * receiving 64-byte packets)
	 *
	 * Any Packets written to the multiplexed channel are similarly adjusted, by
	 * prefixing the packet with the reportID as necessary when converting to a
	 * byte array.
	 */
	private int size;

	public PacketCodec(int size) {
		this.size = size;
	}

	@Override
	protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
		if (in.readableBytes() < size) {
			return;
		}
		while (in.readableBytes() >= size) {
			readCount += size;
			readSinceLast += size;

			byte[] buff = new byte[size];
			in.readBytes(buff);
			if (size > 64) {
				System.arraycopy(buff, size - 64, buff, 0, 64);
			}
			Packet packet = new Packet(buff);
			if (verbose) System.out.println("R: " + packet);
			out.add(packet);
		}
		System.err.print(this);
	}

	@Override
	protected void encode(ChannelHandlerContext ctx, Packet packet, ByteBuf buf) throws Exception {
		if (verbose) System.out.println("W: " + packet);
		byte[] b = packet.getBytes();
		if (b.length < size) {
			byte[] t = new byte[size];
			System.arraycopy(b, 0, t, size - 64, 64);
			b = t;
		}
		buf.writeBytes(b);
		writeCount += size;
		writeSinceLast += size;
		System.err.print(this);
	}

	@Override
	public String toString() {
		long now = System.currentTimeMillis();
		String ret = "";
		if (now - lastPrint > 1000) {
			ret = String.format("R/W (%d, %d) avg R/W (%d, %d), last second R/W (%d, %d)\n", readCount, writeCount, (readCount*1000/(now-epoch)), writeCount*1000/(now-epoch), readSinceLast*1000/(now-lastPrint), writeSinceLast*1000/(now-lastPrint));
			lastPrint = now;
			readSinceLast = 0;
			writeSinceLast = 0;
		}
		return ret;
	}
}