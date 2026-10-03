import { useEffect, useMemo, useRef, useState, useCallback } from "react"; // Added useCallback just in case
import { ChevronDown, X } from "lucide-react";
import Alert from "../Alert";
import { toast } from "../../lib/toast";

export default function ProductModal({
  open,
  mode = "create",
  initialValues,
  sousCategories,
  unites,
  marques,
  onClose,
  onSubmit,
}) {
  const [nameAr, setNameAr] = useState(() => initialValues?.name_ar ?? "");
  const [nameFr, setNameFr] = useState(() => initialValues?.name_fr ?? "");
  const [prix, setPrix] = useState(() => (initialValues?.prix != null ? String(initialValues.prix) : ""));
  const [stock, setStock] = useState(() => (initialValues?.seuil_min != null ? String(initialValues.seuil_min) : ""));
  const [sousCategorieId, setSousCategorieId] = useState(() =>
    initialValues?.sous_categorie_id != null ? String(initialValues.sous_categorie_id) : "",
  );
  const [unite, setUnite] = useState(() => initialValues?.unite ?? "pièce");
  const [codeArticle, setCodeArticle] = useState(() => initialValues?.code_article ?? "");
  const [marqueId, setMarqueId] = useState(() =>
    initialValues?.marque_id != null ? String(initialValues.marque_id) : "",
  );
  const [file, setFile] = useState(null);


  const uniteOptions = useMemo(() => {
    const listFromApi = Array.isArray(unites) ? unites.map((u) => u?.nom).filter(Boolean) : [];
    const base = listFromApi.length ? listFromApi : ["pièce", "kg", "L", "m"];
    const unique = [];
    for (const v of base) {
      const s = String(v);
      if (!unique.includes(s)) unique.push(s);
    }
    if (unite && !unique.includes(unite)) unique.unshift(unite);
    return unique;
  }, [unites, unite]);

  const canSubmit = useMemo(() => {
    const imageOk = mode === "edit" ? true : !!file;
    return (
      imageOk &&
      codeArticle.trim() &&
      (nameAr.trim() || nameFr.trim()) &&
      prix !== "" &&
      sousCategorieId &&
      unite
    );
  }, [codeArticle, nameAr, nameFr, prix, sousCategorieId, unite, file, mode]);

  const handleClose = useCallback(() => {
    onClose?.();
  }, [onClose]);

  useEffect(() => {
    if (!open) return;
    function onKeyDown(e) {
      if (e.key === "Escape") handleClose();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, handleClose]);

  if (!open) return null;

  function submit(e) {
    e.preventDefault();
    if (!canSubmit) return;

    onSubmit?.({
      code_article: codeArticle.trim(),
      name_ar: nameAr.trim(),
      name_fr: nameFr.trim(),
      prix: Number(prix),
      seuil_min: stock === "" ? 0 : Number(stock),
      sous_categorie_id: Number(sousCategorieId),
      marque_id: marqueId ? Number(marqueId) : null,
      unite,
      file,
    });
  }

  return (
    <div className="modal-overlay-product" onMouseDown={handleClose}>
      <div className="modal-product" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head-product">
          <div className="modal-title-product">
            {mode === "edit"
              ? "Modifier le produit"
              : "Ajouter un nouveau produit"}
          </div>
          <button
            className="modal-x-product"
            type="button"
            onClick={handleClose}
            aria-label="Fermer"
          >
            <X size={18} />
          </button>
        </div>

        <form className="modal-body-product" onSubmit={submit}>
          <div className="right-part-product">
                <label className="form-label">
              Code-barres / Code article
              <input
                className="form-input"
                autoFocus
                value={codeArticle}
                onChange={(e) => setCodeArticle(e.target.value)}
                placeholder="Ex: 613000123456"
                required
              />
              <div className="file-hint">
                Scannez le code avec votre lecteur USB.
              </div>
            </label>
            <div className="form-grid">
              <label className="form-label">
                Nom (Français)
                <input 
                  className="form-input"
                  value={nameFr}
                  onChange={(e) => setNameFr(e.target.value)}
                  placeholder="Ex: Tomates"
                />
              </label>

              <label className="form-label">
                Nom (Arabe)
                <input
                  className="form-input"
                  value={nameAr}
                  onChange={(e) => setNameAr(e.target.value)}
                  placeholder="Ex: طماطم"
                  dir="rtl"
                />
              </label>
            </div>

            <div className="form-grid">
              <label className="form-label">
                Prix (DH)
                <input
                  className="form-input form-input-muted"
                  inputMode="decimal"
                  value={prix}
                  onChange={(e) => setPrix(e.target.value)}
                  placeholder="30"
                />
              </label>
              <label className="form-label">
                Stock minimal
                <input
                  className="form-input form-input-muted"
                  inputMode="numeric"
                  value={stock}
                  onChange={(e) => setStock(e.target.value)}
                  placeholder="5"
                />
              </label>
            </div>

            <label className="form-label">
              Unité
              <div className="select-wrap">
                <select
                  className="form-select"
                  value={unite}
                  onChange={(e) => setUnite(e.target.value)}
                >
                  {uniteOptions.map((u) => (
                    <option key={u} value={u}>
                      {u}
                    </option>
                  ))}
                </select>
                <ChevronDown className="select-ico" size={16} />
              </div>
            </label>

            <label className="form-label">
              Catégorie
              <div className="select-wrap">
                <select
                  className="form-select"
                  value={sousCategorieId}
                  onChange={(e) => setSousCategorieId(e.target.value)}
                >
                  <option value="" disabled>
                    Sélectionner
                  </option>
                  {sousCategories.map((sc) => (
                    <option key={sc.id} value={sc.id}>
                      {(sc?.categorie?.nom ? `${sc.categorie.nom} / ` : "") +
                        sc.nom}
                    </option>
                  ))}
                </select>
                <ChevronDown className="select-ico" size={16} />
              </div>
            </label>

            <label className="form-label">
              Marque
              <div className="select-wrap">
                <select
                  className="form-select"
                  value={marqueId}
                  onChange={(e) => setMarqueId(e.target.value)}
                >
                  <option value="">Sans marque</option>
                  {marques?.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.nom}
                    </option>
                  ))}
                </select>
                <ChevronDown className="select-ico" size={16} />
              </div>
            </label>

            <div className="form-label">
              Image du produit
              <div className="file-row">
                <label className="file-btn">
                  Choisir un fichier
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => setFile(e.target.files?.[0] || null)}
                    required={mode !== "edit"}
                    style={{ display: "none" }}
                  />
                </label>
                <div className="file-name">
                  {file ? file.name : "Aucun fichier choisi"}
                </div>
              </div>
              {mode !== "edit" ? (
                <div className="file-hint">
                  Image obligatoire pour créer le produit.
                </div>
              ) : null}
            </div>
             <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={!canSubmit}>
              {mode === "edit" ? "Enregistrer" : "Ajouter"}
            </button>
          </div>
          </div>
        </form>
      </div>
    </div>
  );
}
