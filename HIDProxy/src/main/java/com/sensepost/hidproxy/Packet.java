package com.sensepost.hidproxy;

class Packet {
	static final int SYN=1,ACK=2, FIN=4, RST=8;

	private byte[] packet;

	public Packet() {
		this(new byte[64]);
	}

	public Packet(byte[] packet) {
		this.packet = packet;
	}

	public int getChannel() {
		return packet[0];
	}

	public void setChannel(int channel) {
		packet[0] = (byte) channel;
	}

	public int getFlags() {
		return packet[1];
	}

	public void setFlags(int flags) {
		packet[1] = (byte) flags;
	}

	public int getSeq() {
		return (packet[2] >> 4) & 0x0F;
	}

	public void setSeq(int seq) {
		packet[2] = (byte) ((packet[2] & 0x0F) | (seq << 4));
	}

	public int getAck() {
		return packet[2] & 0xF;
	}

	public void setAck(int ack) {
		packet[2] = (byte) ((packet[2] & 0xF0) | (ack & 0x0F));
	}

	public int length() {
		return packet[3];
	}

	public byte[] getData() {
		int l = length();
		if (l > 0 && l <= 60) {
			byte[] data = new byte[l];
			System.arraycopy(packet, 4, data, 0, l);
			return data;
		} else {
			return new byte[0];
		}
	}

	public void setData(byte[] data) {
		setData(data, 0, data.length);
	}

	public void setData(byte[] data, int off, int len) {
		if (len == 0) {
			return;
		} else if (len > 0 && len <= 60) {
			System.arraycopy(data, off, packet, 4, len);
			packet[3] = (byte) len;
		} else {
			throw new ArrayIndexOutOfBoundsException("Length out of bounds: " + len);
		}
	}

	public byte[] getBytes() {
		return packet;
	}
	private String flagsAsString() {
		StringBuffer b = new StringBuffer();
		String[] flags = new String[] {"SYN", "ACK", "FIN", "RST"};
		int f = getFlags();
		for (int i=0; i<flags.length; i++) {
			if ((f & (1<<i)) == (1<<i)) {
				b.append(",").append(flags[i]);
			}
		}
		if (b.length()>1)
			return b.substring(1);
		return "";
	}

	public String toString() {
		StringBuilder b = new StringBuilder();
		b.append("Channel: ").append(getChannel());
		b.append(", flags=(").append(flagsAsString()).append(")");
		b.append(", seq=").append(getSeq());
		b.append(", ack=").append(getAck());
		b.append(", datalength=").append(packet[3]);
//		b.append(", data='").append(new String(getData())).append("'");
		return b.toString();
	}
}