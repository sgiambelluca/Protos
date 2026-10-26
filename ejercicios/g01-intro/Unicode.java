/*
 * Guía 1 - E6.   Correr (Java 11+ ejecuta un .java suelto):   java Unicode.java
 *
 * "\u1F355" NO es la pizza (U+1F355). El escape \\uXXXX de Java toma
 * EXACTAMENTE 4 dígitos hex: se lee como "\u1F35" (U+1F35, la letra
 * griega ἵ) seguido del carácter '5'. Por eso length() da 2... pero por
 * casualidad: son 2 caracteres distintos.
 *
 * Y aunque se escriba bien la pizza, length() TAMBIÉN da 2, porque los
 * String de Java (y JavaScript) son secuencias de unidades UTF-16: los code
 * points fuera del plano básico (> U+FFFF) ocupan 2 unidades (par subrogado).
 * Para contar "caracteres" de verdad: codePointCount().
 */
public class Unicode {
    public static void main(String[] args) {
        String mal = "\u1F355";                                    // U+1F35 + '5'
        String pizza = new String(Character.toChars(0x1F355));     // U+1F355 de verdad
        String pizza2 = "\uD83C\uDF55";                            // lo mismo, escrito como par subrogado UTF-16

        mostrar("\"\\u1F355\"", mal);
        mostrar("toChars(0x1F355)", pizza);
        mostrar("\"\\uD83C\\uDF55\"", pizza2);
    }

    static void mostrar(String nombre, String s) {
        System.out.printf("%-20s -> %s%n", nombre, s);
        System.out.printf("   length()         = %d  (unidades UTF-16)%n", s.length());
        System.out.printf("   codePointCount() = %d  (code points)%n", s.codePointCount(0, s.length()));
        System.out.print("   code points      =");
        s.codePoints().forEach(cp -> System.out.printf(" U+%04X", cp));
        System.out.printf("%n   bytes UTF-8      = %d%n%n", s.getBytes(java.nio.charset.StandardCharsets.UTF_8).length);
    }
}
